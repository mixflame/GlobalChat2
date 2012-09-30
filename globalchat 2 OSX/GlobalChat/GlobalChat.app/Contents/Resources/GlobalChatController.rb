require 'rubygems'
require 'httparty'

class GlobalChatController
    #include HTTParty
    
    HOST = "globalchatnet.heroku.com"
    #HOST = "localhost:3000"
    
    attr_accessor :chat_token, :chat_buffer, :nicks, :handle, :handle_text_field, :connect_button, :sign_in_window, :chat_window, :chat_window_text, :chat_message, :nicks_table, :application
    
    def quit(sender)
        sign_out
        @application.terminate(self)
    end
    
    def tableView(view, objectValueForTableColumn:column, row:index)
        self.nicks[index]
    end
    
    def numberOfRowsInTableView(view)
        self.nicks.size
    end
    
    def sendMessage(sender)
        @message = sender.stringValue
        post_message(@message)
        @chat_message.setStringValue('')
    end
    
    def signIn(sender)
        sign_on(@handle_text_field.stringValue)
        @sign_in_window.close
        
        queue = Dispatch::Queue.new('com.mdx.globalchat')
        get_log
        sleep 1
        queue.async do
            while 1 do
                get_messages
                get_handles
                sleep 1
            end
        end
        @chat_window.makeKeyAndOrderFront(nil)
        
    end
    
    def update_chat_views
        @chat_window_text.setString(self.chat_buffer)
    end
    
    def sign_on(handle)
        resp = HTTParty::get("http://#{HOST}/signOn?handle=#{handle}").response.body
        ct = resp.split(":")[0]
        nm = resp.split(":")[1]
        self.chat_token = ct
        self.handle = nm
    end
    
    def post_message(message)
        HTTParty::get("http://#{HOST}/postAChatMessage", :query => {:chat_token => @chat_token, :message => message})
    end
    
    def get_log
        self.chat_buffer = HTTParty::get("http://#{HOST}/getChatLog?chat_token=#{self.chat_token}").response.body
        update_chat_views
    end
    
    def get_messages
        self.chat_buffer += HTTParty::get("http://#{HOST}/getMessages?chat_token=#{self.chat_token}").response.body
        update_chat_views
    end
    
    def get_handles
        self.nicks = HTTParty::get("http://#{HOST}/getOnlineHandles?chat_token=#{self.chat_token}").response.body.split("\n")
        @nicks_table.dataSource ||= self
    end

    def sign_out
        HTTParty::get("http://#{HOST}/signOff?chat_token=#{self.chat_token}")
    end

end