# MAX31856

MAX31856 - Precision Thermocouple to Digital Converter with Linearization

Ruby SPI interface using PiPiper


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'max31856'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install max31856


## Usage

    m = MAX31856.new(chip = 0, type = :k, clock = 2_000_000)

    m.config # Must be run once (shutdown resets chip)

    m.read   # [Cold Junction Temp, Thermocouple Temp] Floats in celsius


## Raspberry v3

To enable SPI on the Rpi, on `/boot/config.txt`:

    dtparam=spi=on


## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `rake spec` to run the tests. You can also run `bin/console`
for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`,
and then run `bundle exec rake release`, which will create a git tag
for the version, push git commits and tags, and push the `.gem`
file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nofxx/max31856.
This project is intended to be a safe, welcoming space for collaboration,
and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


## Notes

For RTD -> PT100/PT1000, check out:

https://github.com/nofxx/MAX31865
