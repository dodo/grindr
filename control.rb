require 'xmpp4r/dataforms'
require 'time'

$bot_name = "grindr"
$manual = {:help => "help\nShow the list of all given commands and with a little description.",
           :man => "man <cmd>\nShow a manual of the given command.",
           :mode => "mode <format>\nChange the formatting of the notifications.\n"+
                    "available formats:\n    title -- show only the titles.\n"+
                    "    short -- show titles and fetch status.\n"+
                    "    full -- show full entries. without fetch satus.\n"+
                    "    all -- show all given information.\n    ? -- show current mode.",
           :format => "format <on|off>\nSet xhtml formatting on or off."}

def gen_xhtml(text)
  h = REXML::Element.new "html"
  h.add_namespace 'http://jabber.org/protocol/xhtml-im'
  b = REXML::Element.new "body"
  b.add_namespace 'http://www.w3.org/1999/xhtml'
  a = REXML::Element.new "active"
  a.add_namespace 'http://jabber.org/protocol/chatstates'
  t = REXML::Text.new text, false, nil, true, nil, %r/.^/
  b.add t
  h.add b
  [a, h]
end

class UserController

  def initialize(im, to)
    @im, @to, @mode, @use_xhtml = im, to, :all, true
    puts "* add user "+to.to_s
    @methods = [:on,:off,:list,:help,:ping,:test,:easteregg]
    @functions = [:man,:login,:add,:remove,:mode,:format]
    deliver "Welcome to #{$bot_name}!\nType help for overview.\nCurrent mode is #{@mode.to_s}.","Welcome to <i>#{$bot_name}</i>!\nType <b>help</b> for overview.\nCurrent mode is <b>#{@mode.to_s}</b>."
  end

  def deliver(text, xhtml)
    xhtml = nil unless @use_xhtml
    x = xhtml.nil? ? nil : gen_xhtml(xhtml)
    @im.deliver @to, text, :chat, x
  end

  def receive(msg)
    begin
      if @methods.include? msg.chomp.to_sym
        send msg.chomp.to_sym
      elsif @functions.include? msg.split[0].chomp.to_sym
        send msg.split[0].chomp.to_sym, *msg.split[1..-1]
      else
        deliver "command not found", nil
      end
    rescue Exception => e
      deliver "an error occurred:\n"+e.to_s, nil
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
format <on|off> -- set formatting on or off
help -- show this help
eos
    xhtml = <<eos
[#{$bot_name}] Commands:<br/>
<b>list</b> -- listing feeds<br/>
<b>on</b> -- enable notifications<br/>
<b>off</b> -- disable notification<br/>
<b>add &lt;feedurl&gt;</b> -- adding a feed<br/>
<b>remove &lt;feed&gt;</b> -- removing a feed<br/>
<b>mode &lt;format&gt;</b> -- set notification format<br/>
<b>man &lt;command&gt;</b> -- show a manual of the command<br/>
<b>format &lt;on|off&gt;</b> -- set formatting on or off<br/>
<b>help</b> -- show this help
eos
    deliver text[0..-2], xhtml[0..-2]
  end

  def list
    deliver "not yet implemented.", nil
  end

  def on
    deliver "not yet implemented.", nil
  end

  def off
    deliver "not yet implemented.", nil
  end

  def add(feed)
    deliver "not yet implemented.", nil
  end

  def remove(feed)
    deliver "not yet implemented.", nil
  end

  def login(jid) # why does it not working? :(
    jid = "#{jid}@superfeedr.com" unless jid.index('@')
    deliver "try to login to "+jid, nil

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

  def mode(m="?")
    e = false
    case m
      when "?"     then e=true;deliver "current mode is "+@mode.to_s, "current mode is <b>#{@mode.to_s}</b>"
      when "title" then @mode = :title
      when "short" then @mode = :short
      when "full"  then @mode = :full
      when "all"   then @mode = :all
      else e=true;deliver "mode #{m} not found.", "mode <b>#{m}</b> not found."
    end
    deliver "set mode to " + m, "set mode to <b>#{m}</b>" unless e
  end

  def format(f="?")
    e, s = false, @use_xhtml&&"on"||!@use_xhtml&&"off"
    case f
      when "?"   then e=true;deliver "current formatting is "+s, "current formatting is <b>#{s}</b>"
      when "off" then @use_xhtml = false
      when "on"  then @use_xhtml = true
      else e=true;deliver "format #{f} not found.", "format <b>#{f}</b> not found."
    end
    deliver "set formatting " + f, "set formatting <b>#{f}</b>" unless e
  end

  def man(cmd)
    if $manual.include? cmd.chomp.to_sym
      deliver cmd+" manual:\n"+ $manual[cmd.chomp.to_sym], nil
    else
      deliver "manual for command '#{cmd}' not found.", nil
    end
  end

  def ping
    deliver "pong", nil
  end

  def test
    deliver "Yepp. I'm right here.", nil
  end

  def easteregg
    deliver "You found it ;P", "<span style='font-size: small;'>You found it ;P</span>"
  end

  def notify(event)
    p "here too"
    begin
      event.elements["items"].items.each do |item|
        item.entries.each do |entry|
          unless entry.to_s.strip.empty?
            a, syms = {}, [:title,:published,:content,:summary]
            syms.each { |sym| a[sym] = entry.elements[sym.to_s].nil? ? "" : entry.elements[sym.to_s].text.to_s }
            a[:author] = entry.elements["author"].nil? ? "unknown" : entry.elements["author"].elements["name"].text.to_s
            a[:link] = entry.elements["link"].nil? ? "empty" : entry.elements["link"].attributes["href"].to_s
            a[:content] = a[:summary] if a[:content] == ""
            xcontent = a[:content] == "" ? "" : '<br/>'+a[:content]

            deliver *case @mode
              when :title, :short then ["[#{a[:published]}] #{a[:title]} on [ #{a[:link]} ]","<span style='font-size:small;'>[#{a[:published]}]</span> #{a[:title]} <i>on [ #{a[:link]} ]</i>"]
              when :all, :full then ["#{a[:title]}\n// Posted [#{a[:published]}] from [#{a[:author]}] on [ #{a[:link]} ]\n#{a[:content]}".strip.chomp,"<b>#{a[:title]}</b><br/><span style='font-size:small;'>// Posted [#{a[:published]}] from [#{a[:author]}] <i>on [ #{a[:link]} ]</i></span>#{xcontent}".strip.chomp]
            end
          end
        end
      end
      if [:all, :short].include? @mode
        status = event.elements["status"]
        title = status.elements["title"].text.to_s
        feed = status.attributes["feed"].to_s
        nextf = status.elements["next_fetch"].text.to_s
        fetch = status.elements["http"].text.to_s
        code = status.elements["http"].attributes["code"].to_s

        diff, nextf = Time.parse(nextf) - Time.now(), Time.parse(nextf).to_s
        h, m, s = diff.div(3600), diff.div(60), "%.2f" % (diff % 60)
        time = [ (h.zero? ? nil : "#{h}h"), (m.zero? ? nil : "#{m}m"), "#{s}s"].compact.join " "
        deliver "[#{code}] #{title}\n#{fetch}. Next fetch in #{time} (#{nextf}).  [ #{feed} ]","<span style='font-size:small;'>[#{code}] #{title}<br/>#{fetch}. Next fetch in <b>#{time}</b> (#{nextf}).  <i>[ #{feed} ]</i></span>"
      end
    rescue Exception => e
      deliver "errör: "+e.to_s, nil
    end
  end

end

