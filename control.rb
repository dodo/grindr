

$bot_name = "grindr"
$manual = {:help => "help\nShow the list of all given commands and with a little description.",
           :man => "man <cmd>\nShow a manual of the given command."}


class UserController

  def initialize(im, to)
    @im, @to = im, to
    puts "* add user "+to.to_s
    @methods = [:help,:ping,:test,:easteregg]
    @functions = [:man]
  end

  def deliver(text)
    @im.deliver @to, text
  end

  def receive(msg)
    if @methods.include? msg.chomp.to_sym
      send msg.chomp.to_sym
    elsif @functions.include? msg.split[0].chomp.to_sym
      send msg.split[0].chomp.to_sym, *msg.split[1..-1]
    else
      deliver "command not found"
    end
  end

  def help
    text = <<eos
[#{$bot_name}] Commands:
on -- enable notifications
off -- disable notification
help -- show this help
man <command> -- show a manual of the command
eos
    deliver text[0..-2]
  end

  def man(cmd)
    if $manual.include? cmd.chomp.to_sym
      deliver cmd+" manual:\n"+ $manual[cmd.chomp.to_sym]
    else
      deliver "manual for command '#{cmd}' not found."
    end
  end

  def ping
    deliver "pong"
  end

  def test
    deliver "Yepp. I'm here."
  end

  def easteregg
    deliver "You found it ;P"
  end

end

