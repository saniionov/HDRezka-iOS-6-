#import "HRDatabase.h"
#import "HRMovie.h"

@interface HRDatabase ()
@property (nonatomic, assign) sqlite3 *db;
@end

@implementation HRDatabase

+ (instancetype)sharedDatabase
{
    static HRDatabase *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[HRDatabase alloc] init];
    });
    return _instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self setupDatabase];
    }
    return self;
}

- (void)dealloc
{
    [self closeDatabase];
}

- (void)setupDatabase
{
    if (self.db) return;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDir = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *dbPath = [docsDir stringByAppendingPathComponent:@"hdrezka_storage.sqlite"];
    
    if (sqlite3_open([dbPath UTF8String], &_db) == SQLITE_OK) {
        NSLog(@"[Stage 7.1] База SQLite успешно открыта: %@", dbPath);
        
        char *errMsg = NULL;
        
        const char *favTable = "CREATE TABLE IF NOT EXISTS favorites ("
        "movieId TEXT PRIMARY KEY, "
        "title TEXT, "
        "detailURLString TEXT, "
        "posterURLString TEXT, "
        "info TEXT, "
        "isSeries INTEGER, "
        "season TEXT, "
        "episode TEXT, "
        "translatorId TEXT);";
        sqlite3_exec(self.db, favTable, NULL, NULL, &errMsg);
        
        const char *histTable = "CREATE TABLE IF NOT EXISTS history ("
        "movieId TEXT PRIMARY KEY, "
        "title TEXT, "
        "detailURLString TEXT, "
        "posterURLString TEXT, "
        "info TEXT, "
        "isSeries INTEGER, "
        "season TEXT, "
        "episode TEXT, "
        "translatorId TEXT, "
        "updatedAt INTEGER);";
        sqlite3_exec(self.db, histTable, NULL, NULL, &errMsg);
    } else {
        NSLog(@"[Stage 7.1 Ошибка] Не удалось открыть базу SQLite: %s", sqlite3_errmsg(self.db));
    }
}

- (BOOL)closeDatabase
{
    if (!self.db) return YES;
    
    int result = sqlite3_close(self.db);
    if (result == SQLITE_OK) {
        self.db = NULL;
        return YES;
    }
    
    NSLog(@"[Stage 7.1 Ошибка] Не удалось закрыть SQLite: %s", sqlite3_errmsg(self.db));
    return NO;
}

#pragma mark - Избранное

- (BOOL)addFavorite:(HRMovie *)movie
             season:(NSString *)season
            episode:(NSString *)episode
       translatorId:(NSString *)translatorId
{
    if (!self.db || !movie || !movie.movieId) return NO;
    
    BOOL isSeries = movie.isSeries || ([movie.detailURLString rangeOfString:@"/series/"].location != NSNotFound);
    NSString *sStr = season ?: @"1";
    NSString *eStr = episode ?: @"1";
    NSString *tStr = translatorId ?: @"238";
    
    NSString *posterToSave = movie.posterURLString ?: @"";
    if ([posterToSave length] == 0) {
        // Пробуем восстановить постер из истории, если он там был сохранен ранее
        for (HRMovie *m in [self allHistory]) {
            if ([m.movieId isEqualToString:movie.movieId] && [m.posterURLString length] > 0) {
                posterToSave = m.posterURLString;
                movie.posterURLString = posterToSave;
                break;
            }
        }
    }
    
    NSString *cleanInfo = movie.info ?: @"";
    NSString *progressPrefix = isSeries ? [NSString stringWithFormat:@"[S:%@ E:%@] ", sStr, eStr] : @"";
    NSString *fullDisplayInfo = [NSString stringWithFormat:@"%@%@", progressPrefix, cleanInfo];
    
    const char *query = "INSERT OR REPLACE INTO favorites (movieId, title, detailURLString, posterURLString, info, isSeries, season, episode, translatorId) "
    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);";
    sqlite3_stmt *stmt;
    BOOL success = NO;
    
    if (sqlite3_prepare_v2(self.db, query, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [movie.movieId UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 2, [movie.title UTF8String] ?: "", -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 3, [movie.detailURLString UTF8String] ?: "", -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 4, [posterToSave UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 5, [fullDisplayInfo UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_int(stmt, 6, isSeries ? 1 : 0);
        sqlite3_bind_text(stmt, 7, [sStr UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 8, [eStr UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 9, [tStr UTF8String], -1, SQLITE_TRANSIENT);
        
        if (sqlite3_step(stmt) == SQLITE_DONE) {
            success = YES;
            NSLog(@"[Stage 7.2] Фильм ID %@ сохранен в Избранное (S:%@ E:%@, T:%@)", movie.movieId, sStr, eStr, tStr);
        }
    }
    sqlite3_finalize(stmt);
    return success;
}

- (BOOL)removeFavoriteWithMovieId:(NSString *)movieId
{
    if (!self.db || !movieId) return NO;
    
    const char *query = "DELETE FROM favorites WHERE movieId = ?;";
    sqlite3_stmt *stmt;
    BOOL success = NO;
    
    if (sqlite3_prepare_v2(self.db, query, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [movieId UTF8String], -1, SQLITE_TRANSIENT);
        if (sqlite3_step(stmt) == SQLITE_DONE) {
            success = YES;
            NSLog(@"[Stage 7.2] Фильм ID %@ удален из избранного.", movieId);
        }
    }
    sqlite3_finalize(stmt);
    return success;
}

- (BOOL)isFavorite:(NSString *)movieId
{
    if (!self.db || !movieId) return NO;
    
    const char *query = "SELECT 1 FROM favorites WHERE movieId = ? LIMIT 1;";
    sqlite3_stmt *stmt;
    BOOL exists = NO;
    
    if (sqlite3_prepare_v2(self.db, query, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [movieId UTF8String], -1, SQLITE_TRANSIENT);
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            exists = YES;
        }
    }
    sqlite3_finalize(stmt);
    return exists;
}

- (NSArray *)allFavorites
{
    NSMutableArray *results = [NSMutableArray array];
    if (!self.db) return results;
    
    const char *query = "SELECT movieId, title, detailURLString, posterURLString, info, isSeries, season, episode, translatorId FROM favorites;";
    sqlite3_stmt *stmt;
    
    if (sqlite3_prepare_v2(self.db, query, -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            HRMovie *movie = [[HRMovie alloc] init];
            const char *mId = (const char *)sqlite3_column_text(stmt, 0);
            const char *t = (const char *)sqlite3_column_text(stmt, 1);
            const char *u = (const char *)sqlite3_column_text(stmt, 2);
            const char *p = (const char *)sqlite3_column_text(stmt, 3);
            const char *inf = (const char *)sqlite3_column_text(stmt, 4);
            int isSer = sqlite3_column_int(stmt, 5);
            const char *s = (const char *)sqlite3_column_text(stmt, 6);
            const char *e = (const char *)sqlite3_column_text(stmt, 7);
            const char *tr = (const char *)sqlite3_column_text(stmt, 8);
            
            if (mId) movie.movieId = [NSString stringWithUTF8String:mId];
            if (t) movie.title = [NSString stringWithUTF8String:t];
            if (u) movie.detailURLString = [NSString stringWithUTF8String:u];
            if (p) movie.posterURLString = [NSString stringWithUTF8String:p];
            if (inf) movie.info = [NSString stringWithUTF8String:inf];
            movie.isSeries = (isSer == 1);
            
            NSString *sVal = s ? [NSString stringWithUTF8String:s] : @"1";
            NSString *eVal = e ? [NSString stringWithUTF8String:e] : @"1";
            NSString *trVal = tr ? [NSString stringWithUTF8String:tr] : @"";
            movie.rating = [NSString stringWithFormat:@"%@|%@|%@", sVal, eVal, trVal];
            
            [results addObject:movie];
        }
    }
    sqlite3_finalize(stmt);
    return results;
}

#pragma mark - История просмотров

- (void)savePlaybackHistoryForMovie:(HRMovie *)movie
                             season:(NSString *)season
                            episode:(NSString *)episode
                       translatorId:(NSString *)translatorId
{
    if (!self.db || !movie || !movie.movieId) return;
    
    BOOL isSeries = movie.isSeries || ([movie.detailURLString rangeOfString:@"/series/"].location != NSNotFound);
    NSString *sStr = season ?: @"1";
    NSString *eStr = episode ?: @"1";
    NSString *tStr = translatorId ?: @"238";
    
    NSString *posterToSave = movie.posterURLString ?: @"";
    if ([posterToSave length] == 0) {
        // Подстраховка: проверяем постер в таблице избранного
        for (HRMovie *m in [self allFavorites]) {
            if ([m.movieId isEqualToString:movie.movieId] && [m.posterURLString length] > 0) {
                posterToSave = m.posterURLString;
                movie.posterURLString = posterToSave;
                break;
            }
        }
    }
    
    NSString *cleanInfo = movie.info ?: @"";
    NSString *progressPrefix = isSeries ? [NSString stringWithFormat:@"[S:%@ E:%@] ", sStr, eStr] : @"";
    NSString *fullDisplayInfo = [NSString stringWithFormat:@"%@%@", progressPrefix, cleanInfo];
    
    long long now = (long long)[[NSDate date] timeIntervalSince1970];
    
    // 1. Запись в историю
    const char *query = "INSERT OR REPLACE INTO history (movieId, title, detailURLString, posterURLString, info, isSeries, season, episode, translatorId, updatedAt) "
    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);";
    sqlite3_stmt *stmt;
    
    if (sqlite3_prepare_v2(self.db, query, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [movie.movieId UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 2, [movie.title UTF8String] ?: "", -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 3, [movie.detailURLString UTF8String] ?: "", -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 4, [posterToSave UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 5, [fullDisplayInfo UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_int(stmt, 6, isSeries ? 1 : 0);
        sqlite3_bind_text(stmt, 7, [sStr UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 8, [eStr UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 9, [tStr UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt, 10, now);
        
        if (sqlite3_step(stmt) == SQLITE_DONE) {
            NSLog(@"[Stage 7.3] История просмотра обновлена: '%@' (S:%@ E:%@, T:%@)", movie.title, sStr, eStr, tStr);
        }
    }
    sqlite3_finalize(stmt);
    
    // 2. Синхронизация позиции в Избранном (если фильм там сохранен)
    if ([self isFavorite:movie.movieId]) {
        const char *favUpdate = "UPDATE favorites SET season = ?, episode = ?, translatorId = ?, info = ?, posterURLString = CASE WHEN LENGTH(?) > 0 THEN ? ELSE posterURLString END WHERE movieId = ?;";
        sqlite3_stmt *favStmt;
        if (sqlite3_prepare_v2(self.db, favUpdate, -1, &favStmt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(favStmt, 1, [sStr UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(favStmt, 2, [eStr UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(favStmt, 3, [tStr UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(favStmt, 4, [fullDisplayInfo UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(favStmt, 5, [posterToSave UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(favStmt, 6, [posterToSave UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(favStmt, 7, [movie.movieId UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_step(favStmt);
            NSLog(@"[Stage 7.2] Позиция в Избранном синхронизирована: (S:%@ E:%@)", sStr, eStr);
        }
        sqlite3_finalize(favStmt);
    }
}

- (NSArray *)allHistory
{
    NSMutableArray *results = [NSMutableArray array];
    if (!self.db) return results;
    
    const char *query = "SELECT movieId, title, detailURLString, posterURLString, info, isSeries, season, episode, translatorId FROM history ORDER BY updatedAt DESC;";
    sqlite3_stmt *stmt;
    
    if (sqlite3_prepare_v2(self.db, query, -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            HRMovie *movie = [[HRMovie alloc] init];
            const char *mId = (const char *)sqlite3_column_text(stmt, 0);
            const char *t = (const char *)sqlite3_column_text(stmt, 1);
            const char *u = (const char *)sqlite3_column_text(stmt, 2);
            const char *p = (const char *)sqlite3_column_text(stmt, 3);
            const char *inf = (const char *)sqlite3_column_text(stmt, 4);
            int isSer = sqlite3_column_int(stmt, 5);
            const char *s = (const char *)sqlite3_column_text(stmt, 6);
            const char *e = (const char *)sqlite3_column_text(stmt, 7);
            const char *tr = (const char *)sqlite3_column_text(stmt, 8);
            
            if (mId) movie.movieId = [NSString stringWithUTF8String:mId];
            if (t) movie.title = [NSString stringWithUTF8String:t];
            if (u) movie.detailURLString = [NSString stringWithUTF8String:u];
            if (p) movie.posterURLString = [NSString stringWithUTF8String:p];
            if (inf) movie.info = [NSString stringWithUTF8String:inf];
            movie.isSeries = (isSer == 1);
            
            NSString *sVal = s ? [NSString stringWithUTF8String:s] : @"1";
            NSString *eVal = e ? [NSString stringWithUTF8String:e] : @"1";
            NSString *trVal = tr ? [NSString stringWithUTF8String:tr] : @"";
            movie.rating = [NSString stringWithFormat:@"%@|%@|%@", sVal, eVal, trVal];
            
            [results addObject:movie];
        }
    }
    sqlite3_finalize(stmt);
    return results;
}

@end