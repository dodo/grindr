require 'db'

# just an temporary interface to data
class Memory < PublicDB

  def initialize
    @data = {}
  end

  def create(user)
    @data[user] = {"feeds" => []}
    CONFIG['default'].each { |k,v| @data[user][k] = v }
  end

  def get(user, key)
    @data[user][key]
  end

  def set(user, key, value)
    @data[user][key] = value
    value
  end

  def users
    @data.keys
  end

end

def _db
  Memory
end

