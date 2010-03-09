require 'db'

# interface to the sqlite database
class Sqlite < PublicDB

end

def _db
  Sqlite
end

