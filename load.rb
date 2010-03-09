require 'yaml'
require 'db'

def load_config
  conf = YAML.load File.new('config.yaml')
  unless ['private', 'public'].include? conf['mode']
    puts "Mode not right configured."
    puts "your: #{conf['mode']}"
    puts "should: private or public"
    exit 1
  end
  conf
end

def load_database
  case CONFIG['mode']
    when 'private' then db = PrivateDB
    when 'public'  then db = _db if require CONFIG['public']['db']
  end
  db.new
end

CONFIG = load_config
DB = load_database

