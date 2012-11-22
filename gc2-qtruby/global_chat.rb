class GlobalChat < Qt::Widget

    signals :updateChatViews

    attr_accessor :handles, :chat_window_text, :chat_message, :gcc

    def initialize(handle, host, port, password, parent=nil)
        super parent

        block=Proc.new{ Thread.pass }
        timer=Qt::Timer.new(window)
        invoke=Qt::BlockInvocation.new(timer, block, "invoke()")
        Qt::Object.connect(timer, SIGNAL("timeout()"), invoke, SLOT("invoke()"))
        timer.start(1)

        loader = Qt::UiLoader.new
        file = Qt::File.new 'GlobalChat.ui' do
            open Qt::File::ReadOnly
        end
        window = loader.load file
        file.close

        @handles_list = window.findChild(Qt::ListWidget, "listWidget")
        @chat_window_text = window.findChild(Qt::TextEdit, "textEdit")
        @chat_message = window.findChild(Qt::LineEdit, "lineEdit")

        self.layout = Qt::VBoxLayout.new do |l|
            l.addWidget(window)
        end

        self.windowTitle = tr("GlobalChat")

        # UI ETC
        @chat_message.connect(SIGNAL :returnPressed) { @gcc.sendMessage }

        @gcc = GlobalChatController.new

        @gcc.connect(SIGNAL :updateChatViews) { updateChatViews }

        # binding.pry
        @gcc.handle = handle
        @gcc.host = host
        @gcc.port = port
        @gcc.password = password
        @gcc.nicks = []
        @gcc.chat_buffer = ""
        @gcc.handles_list = @handles_list
        @gcc.chat_message = @chat_message
        @gcc.chat_window_text = @chat_window_text
        @gcc.sign_on

    end

    def updateChatViews
        @chat_window_text.text = @gcc.chat_buffer
        @chat_window_text.verticalScrollBar.setSliderPosition(@chat_window_text.verticalScrollBar.maximum)
    end

end
