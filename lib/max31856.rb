require 'max31856/version'
require 'pi_piper'

#
# MAX31856
#
class MAX31856
  attr_accessor :chip, :type # s, :miso, :mosi, :clk

  # Thermocouple Temperature Data Resolution
  TC_RES = 0.0078125
  # Cold-Junction Temperature Data Resolution
  CJ_RES = 0.015625

  REG_CJ = 0x08 # Fault status register
  REG_TC = 0x0c # Fault status register
  REG_FAULT = 0x0F # Fault status register

  #
  # Config Register 1
  # ------------------
  # bit 7: Conversion Mode                         -> 0 (Normally Off Mode)
  # bit 6: 1-shot                                  -> 1 (ON)
  # bit 5: open-circuit fault detection            -> 0 (off)
  # bit 4: open-circuit fault detection            -> 0 (off)
  # bit 3: Cold-junction temerature sensor enabled -> 0 (default)
  # bit 2: Fault Mode                              -> 0 (default)
  # bit 1: fault status clear                      -> 1 (clear any fault)
  # bit 0: 50/60 Hz filter select                  -> 0 (60Hz)
  #
  REG_01 = [0x00, 0b01000010].freeze

  #
  # Config Register 2
  # ------------------
  # bit 7: Reserved                                -> 0
  # bit 6: Averaging Mode 1 Sample                 -> 0 (default)
  # bit 5: Averaging Mode 1 Sample                 -> 0 (default)
  # bit 4: Averaging Mode 1 Sample                 -> 0 (default)
  # bit 3: Thermocouple Type -> K Type (default)   -> 0 (default)
  # bit 2: Thermocouple Type -> K Type (default)   -> 0 (default)
  # bit 1: Thermocouple Type -> K Type (default)   -> 1 (default)
  # bit 0: Thermocouple Type -> K Type (default)   -> 1 (default)
  #
  REG_02 = [0x01, 0b01000010].freeze

  TYPES = {
    b: 0x00,
    e: 0x01,
    j: 0x02,
    k: 0x03,
    n: 0x04,
    r: 0x05,
    s: 0x06,
    t: 0x07
  }.freeze

  CHIPS = {
    0 => PiPiper::Spi::CHIP_SELECT_0,
    1 => PiPiper::Spi::CHIP_SELECT_1,
    2 => PiPiper::Spi::CHIP_SELECT_BOTH,
    3 => PiPiper::Spi::CHIP_SELECT_NONE
  }.freeze

  def initialize(type = :k, chip = 0, clock = 2_000_000)
    @type = TYPES[type]
    @chip = CHIPS[chip]
    @clock = clock
  end

  def spi_work
    PiPiper::Spi.begin do |spi|
      # Set cpol, cpha
      PiPiper::Spi.set_mode(0, 1)

      # Setup the chip select behavior
      spi.chip_select_active_low(true)

      # Set the bit order to MSB
      spi.bit_order PiPiper::Spi::MSBFIRST

      # Set the clock divider to get a clock speed of 2MHz
      spi.clock @clock

      spi.chip_select(chip) do
        yield spi
      end
    end
  end

  def config
    PiPiper::Spi.begin do |spi|
      # Set cpol, cpha
      PiPiper::Spi.set_mode(0, 1)

      # Setup the chip select behavior
      spi.chip_select_active_low(true)

      # Set the bit order to MSB
      spi.bit_order PiPiper::Spi::MSBFIRST

      # Set the clock divider to get a clock speed of 2MHz
      spi.clock @clock

      sleep 0.5 # give it 500ms for conversion

      # write config Register 0
      # spi.chip_select(chip) do
      # p 'Conv ' + spi.write(REG_01).inspect
      # # sleep 0.2
      # p "Thermo #{type}-> " + spi.write(REG_02).inspect
      # sleep 0.2
      # end

      loop do
        tc = cj = 0
        spi.chip_select(chip) do
          # spi.write(0, 0x42)
          # conversion time is less than 150ms
          sleep(0.2) # give it 200ms for conversion

          cj = read_cj(spi.write(Array.new(4, 0xff).unshift(REG_CJ)))
          sleep 0.2
          tc = read_tc(spi.write(Array.new(4, 0xff).unshift(REG_TC)))
        end
        puts print_c :tc, tc
        puts print_c :cj, cj
        sleep 0.8
        puts '-' * 35
      end
    end
  end

  # Read register faults
  def read_fault
    spi_work do |spi|
      fault = spi.write(REG_FAULT, 0xff)
      p [fault, fault.last.to_s(2).rjust(8, '0')]
    end
  end

  def read_cj(raw)
    p raw
    _, lsb, msb, offset = raw.reverse
    # MSB << 8 | LSB and remove last 2
    temp = ((msb << 8) | lsb) >> 2
    temp = offset + temp
    # Handle negative
    temp -= 0x4000 unless (msb & 0x80).zero?
    # Convert to Celsius
    temp * CJ_RES
  end

  def read_tc(raw)
    _fault, lb, mb, hb = raw.reverse
    temp = ((hb << 16) | (mb << 8) | lb) >> 5

    temp -= 0x80000 unless (hb & 0x80).zero?

    # Convert to Celsius
    temp * TC_RES
  end

  def print_c(label, temp)
    "🌡 #{label}: #{format('%.2f', temp)}℃"
  end

  def read_all
    config
    # PiPiper::Spi.begin(chip) do |spi|
    # end
  end
end
