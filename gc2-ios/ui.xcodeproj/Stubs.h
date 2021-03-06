// Generated by IB v0.1.4 gem. Do not edit it manually
// Run `rake design` to refresh

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <UIKit/UIKit.h>

@interface GlobalChatController : UIViewController

@property IBOutlet id chat_window_text;
@property IBOutlet id nicks_table;
@property IBOutlet id scroll_view;
@property IBOutlet id chat_message;



-(IBAction) textFieldShouldReturn:(id) textField;
-(IBAction) viewWillAppear:(id) animated;
-(IBAction) send_the_chat_message;
-(IBAction) scroll_the_scroll_view_down;
-(IBAction) update_chat_views;
-(IBAction) sign_on;
-(IBAction) update_and_scroll;
-(IBAction) parse_line:(id) line;
-(IBAction) output_to_chat_window:(id) str;
-(IBAction) onSocketDidDisconnect:(id) sock;
-(IBAction) return_to_server_list;
-(IBAction) read_line;
-(IBAction) post_message:(id) message;
-(IBAction) get_log;
-(IBAction) get_handles;
-(IBAction) sign_out;

@end


@interface ServerListController : UIViewController

@property IBOutlet id names;
@property IBOutlet id server_list_table;
@property IBOutlet UITextField * host;
@property IBOutlet UITextField * port;
@property IBOutlet UITextField * password;
@property IBOutlet id handle;



-(IBAction) textFieldShouldReturn:(id) textField;
-(IBAction) load_prefs;
-(IBAction) viewWillAppear:(id) animated;
-(IBAction) get_servers;
-(IBAction) refresh:(id) sender;
-(IBAction) connect:(id) sender;

@end

