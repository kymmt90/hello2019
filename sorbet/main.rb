# typed: true

require 'sorbet-runtime'

class Main
  extend T::Sig

  sig {params(x: String).returns(Integer)}
  def self.main(x)
    x.length
  end

  sig {returns(Integer)}
  def no_params
    42
  end

  sig {void}
  def hello
    puts 'hello'
  end
end
