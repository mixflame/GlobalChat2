require 'mac_bacon'
require '../GlobalChatController.rb'

describe GlobalChatController do
    
    
    it 'should signOn and get a chat_token' do
        @gcc = GlobalChatController.new("jsilver")
        @gcc.get_log
        @gcc.chat_token.should != nil
    end
    
    it 'should post a message' do
        @gcc.post_message("Hi I am A Programmer").should == nil
    end
    
    it 'should get a log' do 
        @gcc.chat_buffer.nil?.should == false
    end
    
    it 'should get messages' do
        cb_before = @gcc.chat_buffer
        @gcc.post_message("I Love You. I Love Ruby")
        @gcc.get_messages
        @gcc.chat_buffer.should != cb_before
    end
    
    it 'should get online handles' do
        @gcc.get_handles
        @gcc.nicks.should != nil
    end
    
    after do
      @gcc.sign_out
    end
end
