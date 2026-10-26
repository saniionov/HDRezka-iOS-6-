#import "HRCatalogParser.h"
#import "HRMovie.h"
#import "HRTranslator.h"

@implementation HRCatalogParser

+ (NSArray *)parseCatalogHTML:(NSString *)html
{
    NSMutableArray *results = [NSMutableArray array];
    if (!html || [html length] == 0) return results;
    
    NSArray *items = [html componentsSeparatedByString:@"class=\"b-content__inline_item\""];
    for (NSUInteger i = 1; i < [items count]; i++) {
        NSString *chunk = [items objectAtIndex:i];
        
        HRMovie *movie = [[HRMovie alloc] init];
        movie.movieId = [self extractBetween:@"data-id=\"" and:@"\"" from:chunk];
        
        // 1. Ссылка
        NSString *link = [self extractBetween:@"<a href=\"" and:@"\"" from:chunk];
        if ([link length] == 0) {
            link = [self extractBetween:@"href=\"" and:@"\"" from:chunk];
        }
        movie.detailURLString = link;
        
        // 2. Постер
        NSString *poster = [self extractBetween:@"data-original=\"" and:@"\"" from:chunk];
        if ([poster length] == 0) {
            poster = [self extractBetween:@"data-src=\"" and:@"\"" from:chunk];
        }
        if ([poster length] == 0) {
            poster = [self extractBetween:@"src=\"" and:@"\"" from:chunk];
        }
        if ([poster rangeOfString:@"spacer.gif"].location != NSNotFound) {
            poster = @"";
        }
        movie.posterURLString = poster;
        
        // 3. Название
        NSString *titleChunk = [self extractBetween:@"b-content__inline_item-link" and:@"</a>" from:chunk];
        if ([titleChunk length] > 0) {
            NSRange gtRange = [titleChunk rangeOfString:@">"];
            if (gtRange.location != NSNotFound) {
                titleChunk = [titleChunk substringFromIndex:gtRange.location + 1];
            }
        } else {
            titleChunk = [self extractBetween:@"class=\"title\">" and:@"<" from:chunk];
        }
        
        if ([titleChunk length] > 0) {
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>" options:0 error:nil];
            titleChunk = [regex stringByReplacingMatchesInString:titleChunk options:0 range:NSMakeRange(0, [titleChunk length]) withTemplate:@""];
            titleChunk = [self cleanHtmlEntities:titleChunk];
            movie.title = [titleChunk stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
        
        // 4. Метаданные (год, страна, жанры) с удалением «Дубляж» и сущностей
        NSString *infoChunk = [self extractBetween:@"<div>" and:@"</div>" from:chunk];
        if (infoChunk && [infoChunk length] > 0) {
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>" options:0 error:nil];
            infoChunk = [regex stringByReplacingMatchesInString:infoChunk options:0 range:NSMakeRange(0, [infoChunk length]) withTemplate:@""];
            infoChunk = [self cleanHtmlEntities:infoChunk];
            movie.info = [infoChunk stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
        
        // 5. Рейтинг
        NSString *ratingChunk = [self extractBetween:@"class=\"rating\">" and:@"<" from:chunk];
        if ([ratingChunk length] == 0) {
            ratingChunk = [self extractBetween:@"<i class=\"i-fav\"></i>" and:@"<" from:chunk];
        }
        movie.rating = [ratingChunk stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        // Признак сериала
        movie.isSeries = ([chunk rangeOfString:@"b-content__inline_item-cover--series"].location != NSNotFound ||
                          [movie.detailURLString rangeOfString:@"/series/"].location != NSNotFound);
        
        if ([movie.title length] > 0) {
            [results addObject:movie];
        }
    }
    return results;
}

+ (NSString *)cleanHtmlEntities:(NSString *)text
{
    if (!text || [text length] == 0) return @"";
    
    NSString *cleaned = text;
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@"&nbsp;" withString:@" "];
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@"$nbsp;" withString:@" "];
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@"&#39;" withString:@"'"];
    
    // Удаление слова «Дубляж»
    NSRegularExpression *dubRegex = [NSRegularExpression regularExpressionWithPattern:@"(?i)\\bдубляж\\b[\\s,:—\\-]*"
                                                                              options:0
                                                                                error:nil];
    cleaned = [dubRegex stringByReplacingMatchesInString:cleaned
                                                 options:0
                                                   range:NSMakeRange(0, [cleaned length])
                                            withTemplate:@""];
    
    NSRegularExpression *spacesRegex = [NSRegularExpression regularExpressionWithPattern:@"\\s+" options:0 error:nil];
    cleaned = [spacesRegex stringByReplacingMatchesInString:cleaned options:0 range:NSMakeRange(0, [cleaned length]) withTemplate:@" "];
    
    cleaned = [cleaned stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([cleaned hasPrefix:@","] || [cleaned hasPrefix:@"-"] || [cleaned hasPrefix:@"•"]) {
        cleaned = [cleaned substringFromIndex:1];
    }
    
    return [cleaned stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (NSString *)extractMovieIDFromHTML:(NSString *)html
{
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"data-id=\"([0-9]+)\"" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:html options:0 range:NSMakeRange(0, html.length)];
    if (match && match.numberOfRanges > 1) {
        return [html substringWithRange:[match rangeAtIndex:1]];
    }
    return @"";
}

+ (NSString *)extractDescriptionFromHTML:(NSString *)html
{
    NSString *desc = [self extractBetween:@"class=\"b-post__description_text\">" and:@"</div>" from:html];
    if ([desc length] > 0) {
        NSRegularExpression *tagRegex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>" options:0 error:nil];
        desc = [tagRegex stringByReplacingMatchesInString:desc options:0 range:NSMakeRange(0, [desc length]) withTemplate:@""];
        desc = [self cleanHtmlEntities:desc];
        return [desc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return @"";
}

+ (NSArray *)parseTranslatorsFromHTML:(NSString *)html
{
    NSMutableArray *translators = [NSMutableArray array];
    
    NSString *container = [self extractBetween:@"id=\"translators-list\"" and:@"</ul>" from:html];
    if ([container length] == 0) {
        container = [self extractBetween:@"class=\"b-translators__list\"" and:@"</ul>" from:html];
    }
    
    if ([container length] > 0) {
        NSArray *items = [container componentsSeparatedByString:@"<li"];
        for (NSString *chunk in items) {
            NSString *tId = [self extractBetween:@"data-translator_id=\"" and:@"\"" from:chunk];
            if ([tId length] > 0) {
                NSString *name = [self extractBetween:@"title=\"" and:@"\"" from:chunk];
                if ([name length] == 0) {
                    name = [self extractBetween:@">" and:@"</li>" from:chunk];
                }
                
                NSRegularExpression *tagRegex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>" options:0 error:nil];
                name = [tagRegex stringByReplacingMatchesInString:name options:0 range:NSMakeRange(0, [name length]) withTemplate:@""];
                name = [self cleanHtmlEntities:name];
                name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                
                if ([name length] == 0) {
                    name = [NSString stringWithFormat:@"Озвучка %@", tId];
                }
                
                BOOL isPrem = ([chunk rangeOfString:@"premium"].location != NSNotFound ||
                               [chunk rangeOfString:@"ico-lock"].location != NSNotFound);
                HRTranslator *t = [[HRTranslator alloc] initWithId:tId name:name isPremium:isPrem];
                [translators addObject:t];
            }
        }
    }
    
    if ([translators count] == 0) {
        NSString *defId = [self extractBetween:@"data-translator_id=\"" and:@"\"" from:html];
        if ([defId length] == 0) defId = @"238";
        HRTranslator *def = [[HRTranslator alloc] initWithId:defId name:@"По умолчанию" isPremium:NO];
        [translators addObject:def];
    }
    
    return translators;
}

+ (NSString *)extractBetween:(NSString *)start and:(NSString *)end from:(NSString *)source
{
    if (!source || !start || !end) return @"";
    NSRange startRange = [source rangeOfString:start];
    if (startRange.location == NSNotFound) return @"";
    
    NSUInteger fromIndex = startRange.location + startRange.length;
    NSRange searchRange = NSMakeRange(fromIndex, [source length] - fromIndex);
    
    NSRange endRange = [source rangeOfString:end options:0 range:searchRange];
    if (endRange.location == NSNotFound) return @"";
    
    return [source substringWithRange:NSMakeRange(fromIndex, endRange.location - fromIndex)];
}

@end