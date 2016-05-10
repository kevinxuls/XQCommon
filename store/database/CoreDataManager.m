//
//  CoreDataManager.m
//  QCCore
//
//  Created by XuQian on 4/18/16.
//  Copyright © 2016 qcwl. All rights reserved.
//

#import "CoreDataManager.h"
#import "QueryFeatures.h"

static inline NSString *DBPath()
{
    NSArray *array = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    return [array.count>0?array.firstObject:@"" stringByAppendingPathComponent:@"db"];
}

@implementation CoreDataManager
{
    @public
    NSURL *_modelURL;
    NSURL *_dbURL;
}

@synthesize managedObjectModel = _managedObjectModel, managedObjectContext = _managedObjectContext, persistentStoreCoordinator = _persistentStoreCoordinator;

+ (instancetype)defaultManager
{
    static CoreDataManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[CoreDataManager alloc] _init];
    });
    return manager;
}

- (id)init
{
    return [CoreDataManager defaultManager];
}

- (id)_init
{
    if (self = [super init]) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:DBPath()]) [[NSFileManager defaultManager] createDirectoryAtPath:DBPath() withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return self;
}

- (void)loadContextWithName:(NSString *)name
{
    if (_managedObjectContext) [self saveContext];
    
    _modelURL = [[NSBundle mainBundle] URLForResource:name withExtension:@"momd"];
    _dbURL = [NSURL fileURLWithPath:[[DBPath() stringByAppendingPathComponent:name] stringByAppendingString:@".sqlite"]];
    _dbName = name;
    
    _managedObjectContext = nil;
    _managedObjectModel = nil;
    _persistentStoreCoordinator = nil;
    [self managedObjectContext];
}

- (void)saveContext
{
    if (!_modelURL || !_dbURL) return;
    
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            DLog(@"%@",[NSError errorWithDomain:@"Unresolved error" code:-1 userInfo:@{@"error":error}]);
        }
    }
}

#pragma mark - Core Data stack

- (NSManagedObjectContext *)managedObjectContext
{
    if (!_managedObjectContext) {
        NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
        if (coordinator != nil) {
            _managedObjectContext = [[NSManagedObjectContext alloc] init];
            [_managedObjectContext setPersistentStoreCoordinator:coordinator];
        }
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (!_managedObjectModel) {
        _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:_modelURL];;
    }
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (!_persistentStoreCoordinator) {
        NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                                  NSInferMappingModelAutomaticallyOption: @YES};
        NSError *error = nil;
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
        if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:_dbURL options:options error:&error]) {
            DLog(@"%@",[NSError errorWithDomain:@"Unresolved error" code:-1 userInfo:@{@"error":error}]);
            _persistentStoreCoordinator = nil;
        }
    }
    return _persistentStoreCoordinator;
}

@end

@implementation CoreDataManager (Utilities)

- (NSArray *)query:(NSString *)entity conditions:(NSArray<QueryPredicate *> *)conditions sorts:(NSArray<QuerySort *> *)sorts limit:(NSUInteger)limit
{
    if (![entity isKindOfClass:[NSString class]]) {
        return [NSArray array];
    }
    
    NSManagedObjectContext *context = [self managedObjectContext];
    
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:entity inManagedObjectContext:context];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    if (conditions != nil && conditions.count > 0) {
        NSMutableArray *array = [NSMutableArray array];
        for (int i=0; i<conditions.count; i++) {
            [array addObject:conditions[i].expression];
        }
        NSString *expression = [conditions componentsJoinedByString:@" AND "];
        [request setPredicate:[NSPredicate predicateWithFormat:expression]];
    }
    
    if (sorts != nil && sorts.count > 0) {
        NSMutableArray *sortDescriptors = [NSMutableArray array];
        for (int i=0; i<sorts.count; i++) {
            NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:sorts[i].attribute ascending:(sorts[i].order==NSOrderedAscending)];
            [sortDescriptors addObject:sortDescriptor];
        }
        [request setSortDescriptors:sortDescriptors];
    }
    
    if ( limit > 0) {
        [request setFetchLimit:limit];
    }
    
    NSError *error;
    NSArray *objects = [context executeFetchRequest:request error:&error];
    
    if (error) {
        CoreLog(@"There was an error:%@",error);
        return nil;
    }
    
    if (!objects) {
        CoreLog(@"Error with NULL array");
        return nil;
    }
    
    return objects;
}

- (NSManagedObject *)create:(NSString *)entity
{
    if (![entity isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSManagedObjectContext *context = [self managedObjectContext];
    
    return [NSEntityDescription insertNewObjectForEntityForName:entity inManagedObjectContext:context];
}

- (void)delete:(NSManagedObject *)object
{
    if (![object isKindOfClass:[NSManagedObject class]]) {
        return;
    }
    NSManagedObjectContext *context = [self managedObjectContext];
    
    [context deleteObject:object];
}

@end

@implementation CoreDataManager (Migration)

- (BOOL)migrateWithNewDBName:(NSString *)name needBackup:(BOOL)backup
{
    NSParameterAssert(name);
    
    if (_managedObjectContext) [self saveContext];
    
    if ([name isEqualToString:_dbName]) return NO;
    
    NSURL *temp = [[NSBundle mainBundle] URLForResource:name withExtension:@"momd"];
    NSManagedObjectModel *destinationModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:temp];
    NSURL *destinationDB = [NSURL fileURLWithPath:[[DBPath() stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"sqlite"]];
    NSMappingModel *mappingModel = [[NSMappingModel alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:name withExtension:@"cdm"]];
    
    NSMigrationManager *manager = [[NSMigrationManager alloc] initWithSourceModel:_managedObjectModel destinationModel:destinationModel];
    BOOL result = [manager migrateStoreFromURL:_dbURL
                                          type:NSSQLiteStoreType
                                       options:@{NSIgnorePersistentStoreVersioningOption:@YES, NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
                              withMappingModel:mappingModel
                              toDestinationURL:destinationDB
                               destinationType:NSSQLiteStoreType
                            destinationOptions:nil
                                         error:nil];
    if (result) {
        if (backup) {
            NSURL *backupURL = [NSURL URLWithString:[_dbURL.absoluteString stringByAppendingString:@"~"]];
            [[NSFileManager defaultManager] moveItemAtURL:_dbURL toURL:backupURL error:nil];
        }else {
            [[NSFileManager defaultManager] removeItemAtURL:_dbURL error:nil];
        }
    }
    
    return result;
}

@end
