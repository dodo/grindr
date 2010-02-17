require 'xmpp4r/dataforms'

$bot_name = "grindr"
$manual = {:help => "help\nShow the list of all given commands and with a little description.",
           :man => "man <cmd>\nShow a manual of the given command.",
           :mode => "mode <format>\nChange the formatting of the notifications.\n"+
                    "available formats:\n    title -- show only the titles.\n"+
                    "    all -- show all given information.\n    ? -- show current mode."}


class UserController

  def initialize(im, to)
    @im, @to, @mode = im, to, :all
    puts "* add user "+to.to_s
    @methods = [:list,:help,:ping,:test,:easteregg]
    @functions = [:man,:login,:add,:remove,:mode]
    deliver "Welcome to #{$bot_name}!\nType help for overview.\nCurrent mode is #{@mode.to_s}."
  end

  def deliver(text)
    @im.deliver @to, text
  end

  def receive(msg)
    begin
      if @methods.include? msg.chomp.to_sym
        send msg.chomp.to_sym
      elsif @functions.include? msg.split[0].chomp.to_sym
        send msg.split[0].chomp.to_sym, *msg.split[1..-1]
      else
        deliver "command not found"
      end
    rescue Exception => e
      deliver "an error occurred:\n"+e.to_s
    end
  end

  def help
    text = <<eos
[#{$bot_name}] Commands:
list -- listing feeds
on -- enable notifications
off -- disable notification
add <feedurl> -- adding a feed
remove <feed> -- removing a feed
mode <format> -- set notification format
man <command> -- show a manual of the command
help -- show this help
eos
    deliver text[0..-2]
  end

  def login(jid)
    jid = "#{jid}@superfeedr.com" unless jid.index('@')
    deliver "try to login to "+jid

    msg = Jabber::Message.new @to
    x = Jabber::Dataforms::XData.new
    f = Jabber::Dataforms::XDataField.new
    f.label= "password"
    f.type= :text_private
    x.type= :form
    x.add f
    msg.add x
    p msg.to_s
    @im.send! msg
  end

  def mode(m)
    e = false
    case m
      when "?"     then e=true;deliver "current mode is "+@mode.to_s
      when "title" then @mode = :title
      when "all"   then @mode = :all
      else e=true;deliver "mode '#{m}' not found."
    end
    deliver "set mode to " + m unless e
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
    deliver "Yepp. I'm right here."
  end

  def easteregg
    deliver "You found it ;P"
  end

  def notify(event)
    p "here too"
    begin
      event.elements["items"].items.each do |item|
        item.entries.each do |entry|
          unless entry.to_s.strip.empty?
            a, syms = {}, [:title,:published,:content,:summary]
            syms.each { |sym| a[sym] = entry.elements[sym.to_s].text.to_s unless entry.elements[sym.to_s].nil? }
            a[:author] = entry.elements["author"].elements["name"].text.to_s
            a[:link] = entry.elements["link"].attributes["href"].to_s
            a[:content] = a[:summary] if a.has_key?(:content) && a.has_key?(:summary)
            
            deliver case @mode
              when :title then "[#{a[:published]}] #{a[:title]}"
              when :all   then "#{a[:title]}\n// Posted [#{a[:published]}] from [#{a[:author]}] on [ #{a[:link]} ]\n#{a[:content]}"
            end
          end
        end
      end
      if @mode == :all
        status = event.elements["status"]
        title = status.elements["title"].text.to_s
        feed = status.attributes["feed"].to_s
        nextf = status.elements["next_fetch"].text.to_s
        fetch = status.elements["http"].text.to_s
        code = status.elements["http"].attributes["code"].to_s
        deliver "[#{code}] #{title}\n#{fetch}. Next fetch in #{nextf}.  [ #{feed} ]"
      end
    rescue Exception => e
      deliver "errör: "+e.to_s
    end
  end

end

