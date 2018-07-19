require 'max31856/version'
require 'pi_piper'

#
# MAX31856
#
class MAX31856
  attr_accessor :chip, :type, :clock

  # Thermocouple Temperature Data Resolution
  TC_RES = 0.0078125
  # Cold-Junction Temperature Data Resolution
  CJ_RES = 0.015625

  # Read registers
  REG_CJ    = 0x08 # Cold Junction status register
  REG_TC    = 0x0c # Thermocouple status register
  REG_FAULT = 0x0F # Fault status register

  # Write registers
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
  REG_1 = 0x00
  CFG_1 = 0b01000010

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
  REG_2 = 0x01

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

  FAULTS = {
    0x80 => 'Cold Junction Out-of-Range',
    0x40 => 'Thermocouple Out-of-Range',
    0x20 => 'Cold-Junction High Fault',
    0x10 => 'Cold-Junction Low Fault',
    0x08 => 'Thermocouple Temperature High Fault',
    0x04 => 'Thermocouple Temperature Low Fault',
    0x02 => 'Overvoltage or Undervoltage Input Fault',
    0x01 => 'Thermocouple Open-Circuit Fault'
  }.freeze

  def initialize(chip = 0, type = :k, clock = 2_000_000)
    @type = TYPES[type]
    @chip = CHIPS[chip]
    @clock = clock
  end

  # Set SPI stuff and yield block
  def spi_work
    PiPiper::Spi.begin do |spi|
      PiPiper::Spi.set_mode(0, 1)
      spi.chip_select_active_low(true)
      spi.bit_order PiPiper::Spi::MSBFIRST
      spi.clock clock

      spi.chip_select(chip) do
        yield spi
      end
    end
  end

  # Set register configs
  def config
    spi_work do |spi|
      # 0x80 to write
      spi.write(0x80 | REG_1, CFG_1)
      spi.write(0x80 | REG_2, type)
    end
    sleep(0.2) # give it 200ms for conversion
  end

  # Read cj and tc
  def read
    tc = cj = 0
    spi_work do |spi|
      cj = read_cj(spi.write(Array.new(4, 0xff).unshift(REG_CJ)))
      sleep 0.2
      tc = read_tc(spi.write(Array.new(4, 0xff).unshift(REG_TC)))
    end
    [tc, cj]
  end

  private

  def read_cj(raw)
    lb, mb, _offset = raw.reverse # Offset already on sum
    # MSB << 8 | LSB and remove last 2
    temp = ((mb << 8) | lb) >> 2

    # Handle negative
    temp -= 0x4000 unless (mb & 0x80).zero?

    # Convert to Celsius
    temp * CJ_RES
  end

  def read_tc(raw)
    fault, lb, mb, hb = raw.reverse
    FAULTS.each do |f, txt|
      raise txt if fault & f == 1
    end
    # MSB << 8 | LSB and remove last 5
    temp = ((hb << 16) | (mb << 8) | lb) >> 5

    # Handle negative
    temp -= 0x80000 unless (hb & 0x80).zero?

    # Convert to Celsius
    temp * TC_RES
  end

  # Read register faults
  def read_fault
    spi_work do |spi|
      fault = spi.write(REG_FAULT, 0xff)
      p [fault, fault.last.to_s(2).rjust(8, '0')]
    end
  end
end
