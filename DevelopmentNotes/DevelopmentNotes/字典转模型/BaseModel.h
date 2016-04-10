//
//  BaseModel.h
//  DevelopmentNotes
//
//  Created by QUAN on 16/4/10.
//  Copyright © 2016年 QUAN. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BaseModel : NSObject
/*
 * 字典转模型
 */
+ (instancetype)initWithDictionary:(NSDictionary *)dict;

@end
