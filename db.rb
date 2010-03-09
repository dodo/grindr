require 'load'


class Database

  def get(user,key)
    raise "get not implemented"
  end
  def set(user,key,value)
    raise "set not implemented"
  end
  def close
  end

end


class PrivateDB < Database

  def initialize
    unless CONFIG['private'].has_key? "settings"
      CONFIG['private']['settings'] = {}
      CONFIG['default'].each { |k,v| CONFIG['private']['settings'][k] = v } 
    end
  end

  def get(_, key)
    CONFIG['private']['settings'][key]
  end

  def set(_, key, value)
    CONFIG['private']['settings'][key] = value
    value
  end

  def close
    File.open('config.yaml', 'w') {|f| f.write(CONFIG.to_yaml) }
  end

end


class PublicDB < Database

  def create(user)
    raise "create not implemented"
  end

end


