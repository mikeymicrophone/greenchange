module ChannelHelper

  def message_content(message)
    %(<div class="message #{message.level}" id="message-#{message.id}"><span class="time">#{message.created_at.strftime('%R')}</span> <span class="sender">#{message.sender_name}</span> <span class="content">#{message.content}</span></div>)
  end

end


  
  