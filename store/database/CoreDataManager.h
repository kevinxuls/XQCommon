//
//  CoreDataManager.h
//  QCCore
//
//  Created by XuQian on 4/18/16.
//  Copyright © 2016 qcwl. All rights reserved.
//

#import <CoreData/CoreData.h>

@class QueryPredicate;
@class QuerySort;

@interface CoreDataManager : NSObject

@property (readonly, strong, nullable) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nullable) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nullable) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nullable, readonly, strong) NSString *dbName;

+ (nonnull instancetype)defaultManager;

- (void)loadContextWithName:(nonnull NSString *)name;
- (void)saveContext;

@end

@interface CoreDataManager (Utilities)

- (nullable NSArray *)query:(nonnull NSString *)entity conditions:(nullable NSArray<QueryPredicate *> *)conditions sorts:(nullable NSArray<QuerySort *> *)sorts limit:(NSUInteger)limit;
- (nullable NSManagedObject *)create:(nonnull NSString *)entity;
- (void)delete:(nonnull NSManagedObject *)object;

@end

@interface CoreDataManager (Migration)

- (BOOL)migrateWithNewDBName:(nonnull NSString *)name needBackup:(BOOL)backup;

@end
