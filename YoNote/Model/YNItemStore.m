//
//  YNItemStore.m
//  YoNote
//
//  Created by Zchan on 15/5/23.
//  Copyright (c) 2015年 Zchan. All rights reserved.
//

#import "YNItemStore.h"

@interface YNItemStore ()

@property (nonatomic) NSMutableArray *privateItems;
@property (nonatomic) NSMutableArray *privateCollections;
@property (nonatomic) NSMutableArray *privateTags;
@property (nonatomic) NSMutableArray *privateImages;
@property (nonatomic, strong) NSManagedObjectContext *context;
@property (nonatomic, strong) NSManagedObjectModel *model;

@end

@implementation YNItemStore

#pragma mark - Init

+ (instancetype)sharedStore
{
    static YNItemStore *sharedStore = nil;
    if (!sharedStore) {
        sharedStore = [[self alloc] initPrivate];
    }
    return sharedStore;
}

- (instancetype)init
{
    @throw [NSException exceptionWithName:@"Singleton" reason:@"Use + [[YNItemStore alloc] sharedStore]" userInfo:nil];
    return nil;
}

- (instancetype)initPrivate
{
    self = [super init];
    if (self) {
        //  从YoNote.xcdatamoeld中读取实体信息来创建模型对象
        _model = [NSManagedObjectModel mergedModelFromBundles:nil];
        
        //  创建psc
        NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_model];
        
        //  指定持久化文件的存储路径
        NSString *path = self.itemArchivePath;
        NSURL *storeURL = [NSURL fileURLWithPath:path];
        NSError *error;
        //  指定存储格式为SQLite
        if (![psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
            @throw [NSException exceptionWithName:@"OpenFailure"
                                           reason:[error localizedDescription]
                                         userInfo:nil];
        }
        // 创建NSManagedObjectContext
        _context = [[NSManagedObjectContext alloc]init];
        _context.persistentStoreCoordinator = psc;
        // 如果已经有数据存在，取出
        [self loadAllItems];
        [self loadAllCollections];
        [self loadAllTags];
        
    }
    
    return  self;
}

#pragma mark - Item

- (NSArray *)allItems
{
    return [self.privateItems copy];
}

- (BOOL)saveChanges
{
    NSError *error;
    BOOL successful = [self.context save:&error];
    if (!successful) {
        NSLog(@"Error saving: %@", [error localizedDescription]);
    }
    return successful;
}

- (YNItem *)createItem
{
    YNItem *item = [NSEntityDescription insertNewObjectForEntityForName:@"YNItem" inManagedObjectContext:self.context];
    [self.privateItems addObject:item];
    
    return item;
}

- (void)removeItem:(YNItem *)item
{
    [self.context deleteObject:item];
    [self.privateItems removeObjectIdenticalTo:item];
}

- (void)loadAllItems
{
    if (!self.privateItems) {
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"YNItem" inManagedObjectContext:self.context];
        request.entity = entity;
        
        NSError *error;
        NSArray *result = [self.context executeFetchRequest:request error:&error];
        
        if (!result) {
            [NSException raise:@"Fetch failed" format:@"Reason: %@", [error localizedDescription]];
        }
        
        self.privateItems = [[NSMutableArray alloc] initWithArray:result];
        
    }
}

#pragma mark - Collection

- (NSArray *)allCollections {
    return [self.privateCollections copy];
}

- (void)createCollection:(NSString *)collectionName {
    YNCollection *collection = [NSEntityDescription insertNewObjectForEntityForName:@"YNCollection" inManagedObjectContext:self.context];
    
    [collection setValue:collectionName forKey:@"collectionName"];
    [self.privateCollections addObject:collection];
}

- (void)removeCollection:(YNCollection *)collection {
    [self.context deleteObject:collection];
    [self.privateCollections removeObjectIdenticalTo:collection];
}

- (void)addCollectionForItem:(NSString *)collectionName forItem:(YNItem *)item {
    YNCollection *collection = [self getCollectionByName:collectionName];
    [collection addItemsObject:item];
}

- (YNCollection *)getCollectionByName:(NSString *)collectionName {
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"YNCollection"];
    
    request.predicate = [NSPredicate predicateWithFormat:@"%K=%@",@"collectionName", collectionName];
    
    NSError *error;
    YNCollection *collection;
    
    NSArray *results = [self.context executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"Error：%@！",error.localizedDescription);
    } else {
        collection = [results firstObject];
    }
    return collection;
    
}

- (void)loadAllCollections {
    if (!self.privateCollections) {
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"YNCollection" inManagedObjectContext:self.context];
        request.entity = entity;
        
        NSError *error;
        NSArray *result = [self.context executeFetchRequest:request error:&error];
        
        if (!result) {
            [NSException raise:@"Fetch failed" format:@"Reason: %@", [error localizedDescription]];
        }
        self.privateCollections = [[NSMutableArray alloc] initWithArray:result];
    }
    
}

#pragma mark - Tags
- (NSArray *)allTags {
    return [self.privateTags copy];
}

- (void)createTag:(NSString *)tagName {
    YNTag *tag = [NSEntityDescription insertNewObjectForEntityForName:@"YNTag" inManagedObjectContext:self.context];

    [tag setValue:tagName forKey:@"tag"];
    
    [self.privateTags addObject:tag];

}

- (void)removeTag:(YNTag *)tag {
    [self.context deleteObject:tag];
    [self.privateTags removeObjectIdenticalTo:tag];
}

- (void)addTagsForItem:(NSSet *)tags forItem:(YNItem *)item {
    for (NSString *tagName in tags) {
        YNTag *tag = [self getTagByName:tagName];
        [item addTagsObject:tag];
    }
}

- (YNTag *)getTagByName: (NSString *)tagName {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"YNTag"];
    
    request.predicate = [NSPredicate predicateWithFormat:@"%K=%@",@"tag", tagName];
    
    NSError *error;
    YNTag   *tag;
    
    NSArray *results = [self.context executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"getTagByName, Error：%@！",error.localizedDescription);
    } else {
        tag = [results firstObject];
    }
    return tag;
}

- (NSArray *)getTagsByItem: (YNItem *)item {
    
    NSMutableArray *itemTags = [NSMutableArray array];
    
    for (NSString *tag in item.tags) {
        [itemTags addObject:tag];
    }
    
    return itemTags;
}

- (void)loadAllTags {
    if (!self.privateTags) {
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"YNTag" inManagedObjectContext:self.context];
        request.entity = entity;
        
        NSError *error;
        NSArray *result = [self.context executeFetchRequest:request error:&error];
        
        if (!result) {
            [NSException raise:@"Fetch All Tags failed" format:@"Reason: %@", [error localizedDescription]];
        }
        
        self.privateTags = [[NSMutableArray alloc] initWithArray:result];
    }
    
}

#pragma mark - Images

- (NSArray *)allImages {
    return [self.privateImages copy];
}

- (void)createImage:(NSString *)imageName {
    YNImage *image = [NSEntityDescription insertNewObjectForEntityForName:@"YNImage" inManagedObjectContext:self.context];
    
    [image setValue:imageName forKey:@"imageName"];
    
    [self.privateImages addObject:image];
}

- (void)removeImage:(YNImage *)image {
    [self.context deleteObject:image];
    [self.privateImages removeObjectIdenticalTo:image];
}

- (void)addImagesForItem:(NSSet *)images forItem:(YNItem *)item {
    for (NSString *imageName in images) {
        YNImage *image = [self getImageByName:imageName];
        [item addImagesObject:image];
    }
}

- (YNImage *)getImageByName: (NSString *)imageName {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"YNImage"];
    
    request.predicate = [NSPredicate predicateWithFormat:@"%K=%@",@"imageName", imageName];
    
    NSError *error;
    YNImage *image;
    
    NSArray *results = [self.context executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"getImageByName, Error：%@！",error.localizedDescription);
    } else {
        image = [results firstObject];
    }
    return image;
}

- (NSArray *)getImagesByItem:(YNItem *)item
{
    NSFetchRequest *request=[NSFetchRequest fetchRequestWithEntityName:@"YNImage"];
    request.predicate=[NSPredicate predicateWithFormat:@"%K=%@",@"imageItem",item];
    NSError *error;
    NSArray *results=[self.context executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"getImagesByItem Error：%@！",error.localizedDescription);
    }
    return results;
}

- (NSArray *)getSameNameImages:(YNImage *)image {
    NSString *imageName = image.imageName;
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"YNImage"];
    request.predicate = [NSPredicate predicateWithFormat:@"%K=%@",@"imageName", imageName];
    NSError *error;
    NSArray *results = [self.context executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"getImagesByItem Error：%@！",error.localizedDescription);
    }
    return results;
}

- (NSArray *)getImageNamesByItem:(YNItem *)item {
    NSMutableArray *imageNames = [NSMutableArray array];
    
    for (YNImage * image in item.images) {
        [imageNames addObject:image.imageName];
    }
    
    return imageNames;
}

#pragma mark - Private Methods

- (NSString *)itemArchivePath
{
    NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [documentDirectories firstObject];
    
    return [documentDirectory stringByAppendingPathComponent:@"store.data"];
}



@end
