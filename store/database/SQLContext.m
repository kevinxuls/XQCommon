//
//  SQLContext.m
//  QCCore
//
//  Created by XuQian on 2/14/16.
//  Copyright © 2016 qcwl. All rights reserved.
//

#import "SQLContext.h"

SortType * const SortASCType = @"ASC";
SortType * const SortDESCType = @"DESC";

SQLColumn SQLColumnMake(const char *name, SQLColumnType type)
{
    struct SQLColumn column;
    column.name = name;
    column.typeValue = type;
    switch (type) {
        case ColumnIntegerType: column.type = "INTEGER";
            break;
        case ColumnFloatType: column.type = "REAL";
            break;
        case ColumnTextType: column.type = "TEXT";
            break;
        case ColumnBlobType: column.type = "BLOB";
            break;
    }
    return column;
}

@implementation SQLValue
{
    @public
    SQLColumn _column;
    id _value;
}
@synthesize column = _column, value = _value;

- (NSString *)description
{
    NSMutableString *str = [NSMutableString stringWithString:[super description]];
    if (_column.typeValue == ColumnBlobType) {
        [str appendFormat:@"name: %s, type: %s, length: %lu",_column.name, _column.type, (unsigned long)[_value length]];
    }else {
        [str appendFormat:@"name: %s, type: %s, value: %@",_column.name, _column.type, _value];
    }
    return str;
}

@end

SQLValue *SQLValueMake(SQLColumn column, id value)
{
    SQLValue *obj = [[SQLValue alloc] init];
    obj->_column = column;
    obj->_value = value;
    return obj;
}

@implementation SQLContext
{
    NSString *_dbPath;
    sqlite3 *_db;
    NSLock *_operationLock;
}

- (id)initWithDBName:(NSString *)dbName
{
    if (self = [super init]) {
        _dbName = dbName;
        _operationLock = [[NSLock alloc] init];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *path = [paths.firstObject stringByAppendingPathComponent:@"DB"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        }
        _dbPath = [path stringByAppendingPathComponent:_dbName];
    }
    return self;
}

- (void)removeDB
{
    [[NSFileManager defaultManager] removeItemAtPath:_dbPath error:nil];
}

- (sqlite3 *)openDB
{
    if (sqlite3_open([_dbPath UTF8String], &_db) != SQLITE_OK) {
        return nil;
    }
    return _db;
}

- (void)closeDBWithSTMT:(sqlite3_stmt *)stmt
{
    sqlite3_finalize(stmt);
    sqlite3_close(_db);
}

- (BOOL)checkTableExist:(NSString *)tableName
{
    if (!tableName || tableName.length == 0) return NO;
    if (![self openDB]) return NO;
    
    NSMutableString *sqlString = [NSMutableString stringWithFormat:@"SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = '%@'", tableName];
    [_operationLock lock];
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(_db, [sqlString UTF8String], -1, &st, NULL) == SQLITE_OK) {
        if (sqlite3_step(st) == SQLITE_ROW && sqlite3_column_int(st, 0) != 0) {
            [self closeDBWithSTMT:st];
            [_operationLock unlock];
            return YES;
        }
        [self closeDBWithSTMT:st];
        [_operationLock unlock];
        return NO;
    }else {
        [self closeDBWithSTMT:st];
        //operation failed
        [_operationLock unlock];
        return NO;
    }
}

- (BOOL)createTable:(NSString *)tableName params:(SQLColumn[])params count:(int)count
{
    if (!tableName || tableName.length == 0) return NO;
    if (params == NULL || params[0].name == NULL) return NO;
    if (![self openDB]) return NO;
    
    NSMutableString *sqlString = [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (id INTEGER PRIMARY KEY AUTOINCREMENT,", tableName];
    
    for (int i= 0; i<count; i++) {
        [sqlString appendFormat:@" %s %s,",params[i].name, params[i].type];
    }
    
    [sqlString replaceCharactersInRange:NSMakeRange(sqlString.length-1, 1) withString:@")"];
    
    [_operationLock lock];
    sqlite3_stmt *st = nil;
    if (sqlite3_prepare_v2(_db, [sqlString UTF8String], -1, &st, NULL) == SQLITE_OK && sqlite3_step(st) == SQLITE_DONE) {
        [self closeDBWithSTMT:st];
        [_operationLock unlock];
        return YES;
    }
    [self closeDBWithSTMT:st];
    //operation failed
    [_operationLock unlock];
    return NO;
}

#pragma mark - add, delete, update, query

- (BOOL)create:(NSString *)tableName params:(NSArray<SQLValue *> *)params
{
    if (!params || params.count == 0) return NO;
    if (![self openDB]) return NO;
    
    NSMutableString *keys = [NSMutableString string];
    NSMutableString *values = [NSMutableString string];
    
    for (int i=0; i<params.count; i++) {
        [keys appendFormat:@"%s, ", params[i].column.name];
        [values appendString:@"?, "];
    }
    [keys deleteCharactersInRange:NSMakeRange(keys.length-2, 2)];
    [values deleteCharactersInRange:NSMakeRange(values.length-2, 2)];
    
    NSMutableString *sqlString = [NSMutableString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", tableName, keys, values];
    
    [_operationLock lock];
    sqlite3_stmt *st = nil;
    int result = sqlite3_prepare_v2(_db, [sqlString UTF8String], -1, &st, nil);
    if (result == SQLITE_OK) {
        
        for (int i=0; i<params.count; i++) {
            
            switch (params[i].column.typeValue) {
                case ColumnIntegerType: {
                    sqlite3_bind_int64(st, i+1, [params[i].value longLongValue]);
                } break;
                case ColumnFloatType: {
                    sqlite3_bind_double(st, i+1, [params[i].value doubleValue]);
                } break;
                case ColumnBlobType: {
                    NSData *data = params[i].value;
                    sqlite3_bind_blob64(st, i+1, [data bytes], data.length, SQLITE_STATIC);
                } break;
                default: {
                    sqlite3_bind_text(st, i+1, [[params[i].value description] UTF8String], -1, SQLITE_STATIC);
                } break;
            }
        }
        
        if (sqlite3_step(st) == SQLITE_DONE) {
            [self closeDBWithSTMT:st];
            [_operationLock unlock];
            return YES;
        }
    }
    [self closeDBWithSTMT:st];
    //operation failed
    [_operationLock unlock];
    return NO;
}

- (BOOL)delete:(NSString *)tableName byID:(NSString *)aID
{
    if (!aID || aID.length == 0) return NO;
    if (![self openDB]) return NO;
    
    NSMutableString *sqlString = [NSMutableString stringWithFormat:@"DELETE FROM %@ WHERE id = %@", tableName, aID];
    
    [_operationLock lock];
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(_db, [sqlString UTF8String], -1, &st, nil) == SQLITE_OK && sqlite3_step(st) == SQLITE_DONE) {
        [self closeDBWithSTMT:st];
        [_operationLock unlock];
        return YES;
    }else {
        [self closeDBWithSTMT:st];
        //operation failed
        [_operationLock unlock];
        return NO;
    }
}

- (BOOL)clean:(NSString *)tableName sort:(NSDictionary<NSString *, SortType *> *)sort limit:(int)limit
{
    if (![self openDB]) return NO;
    
    NSMutableString *sqlString = [NSMutableString stringWithFormat:@"DELETE FROM %@", tableName];
    
    if (limit > 0) {
        
        if (sort && sort.count > 0) {
            [sqlString appendString:@" ORDER BY"];
            for (int i=0; i<sort.allKeys.count; i++) {
                NSString *key = sort.allKeys[i];
                NSString *value = sort[key];
                if ([value isEqualToString:@"DESC"]) {
                    [sqlString appendFormat:@" %@ %@,", key, value];
                }else {
                    [sqlString appendFormat:@" %@,", key];
                }
            }
            [sqlString deleteCharactersInRange:NSMakeRange(sqlString.length-1, 1)];
        }
        
        [sqlString appendFormat:@" LIMIT 0,%d",limit];
    }
    
    [_operationLock lock];
    sqlite3_stmt *st;
    int result = sqlite3_prepare_v2(_db, [sqlString UTF8String], -1, &st, nil);
    if (result == SQLITE_OK) {
        sqlite3_step(st);
        [self closeDBWithSTMT:st];
        [_operationLock unlock];
        return YES;
    }else {
        [self closeDBWithSTMT:st];
        //operation failed
        [_operationLock unlock];
        return NO;
    }
}

- (BOOL)update:(NSString *)tableName value:(id)value forKey:(NSString *)key byID:(NSString *)aID
{
    if (!key || key.length == 0) return NO;
    if (!aID || aID.length == 0) return NO;
    if (![self openDB]) return NO;
    
    NSMutableString *sqlString = [NSMutableString stringWithFormat:@"UPDATE %@ SET %@ = '%@' WHERE id = %@", tableName, key, value, aID];
    
    [_operationLock lock];
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(_db, [sqlString UTF8String], -1, &st, nil) == SQLITE_OK) {
        sqlite3_step(st);
        [self closeDBWithSTMT:st];
        [_operationLock unlock];
        return YES;
    }else {
        [self closeDBWithSTMT:st];
        //operation failed
        [_operationLock unlock];
        return NO;
    }
}

- (NSArray *)query:(NSString *)tableName conditions:(NSString *)conditions limit:(unsigned int)limit sort:(NSDictionary *)sort
{
    if (![self openDB]) return nil;
    
    NSMutableString *querySQL = [NSMutableString stringWithFormat:@"SELECT * FROM %@", tableName];
    
    if (conditions && conditions.length > 0) {
        [querySQL appendFormat:@" WHERE %@", conditions];
    }
    
    if (limit > 0) {
        [querySQL appendFormat:@" LIMIT 0,%d",limit];
    }
    
    if (sort && sort.count > 0) {
        [querySQL appendString:@" ORDER BY"];
        for (int i=0; i<sort.allKeys.count; i++) {
            NSString *key = sort.allKeys[i];
            NSString *value = sort[key];
            if ([value.uppercaseString isEqualToString:SortDESCType]) {
                [querySQL appendFormat:@" %@ %@,", key, value];
            }else {
                [querySQL appendFormat:@" %@,", key];
            }
        }
        [querySQL deleteCharactersInRange:NSMakeRange(querySQL.length-1, 1)];
    }
    
    [_operationLock lock];
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(_db, [querySQL UTF8String], -1, &st, NULL) == SQLITE_OK) {
        NSMutableArray *objects = [NSMutableArray array];
        while (sqlite3_step(st) == SQLITE_ROW) {
            NSMutableDictionary *obj = [NSMutableDictionary dictionary];
            int count = sqlite3_column_count(st);
            for (int row=0; row<count; row++) {
                NSString *key = [NSString stringWithUTF8String:sqlite3_column_name(st, row)];
                if (sqlite3_column_type(st, row) == SQLITE_INTEGER) {
                    [obj setObject:[NSNumber numberWithLongLong:sqlite3_column_int64(st, row)] forKey:key];
                }else if (sqlite3_column_type(st, row) == SQLITE_FLOAT) {
                    [obj setObject:[NSNumber numberWithDouble:sqlite3_column_double(st, row)] forKey:key];
                }else if (sqlite3_column_type(st, row) == SQLITE_TEXT) {
                    NSString *str = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(st, row)];
                    [obj setObject:str?str:@"" forKey:key];
                }else if (sqlite3_column_type(st, row) == SQLITE_BLOB) {
                    const char *dataBuffer = sqlite3_column_blob(st, row);
                    int dataSize = sqlite3_column_bytes(st, row);
                    if (dataBuffer != NULL) {
                        NSData *data = [NSData dataWithBytes:(const void *)dataBuffer length:(NSUInteger)dataSize];
                        [obj setObject:data?data:[NSNull null] forKey:key];
                    }else {
                        [obj setObject:[NSNull null] forKey:key];
                    }
                }else {
                    [obj setObject:[NSNull null] forKey:key];
                }
            }
            [objects addObject:obj];
        }
        [self closeDBWithSTMT:st];
        [_operationLock unlock];
        return objects;
    }
    [self closeDBWithSTMT:st];
    [_operationLock unlock];
    return nil;
}

@end
