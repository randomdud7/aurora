#import "RootListController.h"
#import <UIKit/UIKit.h>
#import <spawn.h>

static void AURKillall(const char *path) {
    pid_t pid;
    const char *argv[] = {"killall", "-9", "SpringBoard", NULL};
    const char *envp[] = {NULL};
    if (access(path, X_OK) == 0) {
        posix_spawn(&pid, path, NULL, NULL, (char *const *)argv, (char *const *)envp);
    }
}

@implementation RootListController

/* PSListController resolves "Root.plist" from the class name (RootListController → Root). */
- (NSArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target {
    return [super loadSpecifiersFromPlistName:name target:target];
}

- (void)respring:(PSSpecifier *)specifier {
    [self.view.window endEditing:YES];
    AURKillall("/usr/bin/killall");
    AURKillall("/bin/killall");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Aurora";
}

@end
