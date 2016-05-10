//
//  SQLContext.h
//  QCCore
//
//  Created by XuQian on 2/14/16.
//  Copyright © 2016 qcwl. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sqlite3.h>

typedef NS_OPTIONS(int, SQLColumnType) {
    ColumnIntegerType       = SQLITE_INTEGER,
    ColumnFloatType         = SQLITE_FLOAT,
    ColumnTextType          = SQLITE_TEXT,
    ColumnBlobType          = SQLITE_BLOB
};

struct SQLColumn {
    const char * name;
    const char * type;
    SQLColumnType typeValue;
};
typedef struct SQLColumn SQLColumn;
FOUNDATION_EXTERN SQLColumn SQLColumnMake(const char *name, SQLColumnType type);

@interface SQLValue : NSObject
@property (nonatomic, assign, readonly) SQLColumn column;
@property (nonatomic, strong, readonly) id value;
@end

FOUNDATION_EXTERN SQLValue *SQLValueMake(SQLColumn column, id value);

typedef NSString SortType;
FOUNDATION_EXTERN SortType * const SortASCType;
FOUNDATION_EXTERN SortType * const SortDESCType;

@interface SQLContext : NSObject

@property (nonatomic, strong, readonly) NSString *dbName;

- (id)initWithDBName:(NSString *)dbName;
- (id)init NS_UNAVAILABLE;

- (BOOL)checkTableExist:(NSString *)tableName;
- (BOOL)createTable:(NSString *)tableName params:(SQLColumn[])params count:(int)count;

- (BOOL)create:(NSString *)tableName params:(NSArray<SQLValue *> *)params;
- (BOOL)delete:(NSString *)tableName byID:(NSString *)aID;
- (BOOL)clean:(NSString *)tableName sort:(NSDictionary<NSString *, SortType *> *)sort limit:(int)limit;
- (BOOL)update:(NSString *)tableName value:(id)value forKey:(NSString *)key byID:(NSString *)aID;
- (NSArray *)query:(NSString *)tableName conditions:(NSString *)conditions limit:(unsigned int)limit sort:(NSDictionary *)sort;

- (void)removeDB;

@end
