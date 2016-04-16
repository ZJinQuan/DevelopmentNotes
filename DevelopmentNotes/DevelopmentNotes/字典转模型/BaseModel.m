//
//  BaseModel.m
//  DevelopmentNotes
//
//  Created by QUAN on 16/4/10.
//  Copyright © 2016年 QUAN. All rights reserved.
//

#import "BaseModel.h"
#import <objc/runtime.h>

@implementation BaseModel

+(instancetype)initWithDictionary:(NSDictionary *)dict
{
    /*
     
     该方法会自动给模型赋值，其中NSString与NSNumber会互相转换，如果模型中有为nil的JSON解析类型的属性，会先自动赋一
     个默认值,NSString默认为@"",NSNumber默认为NSNotFound，NSArray与NSDictionary会默认一个空的数组或字典，然后再
     根据数据源进行赋值操作
     
     */
    
    id obj = [[self alloc] init];
    
    [self ModelAttributeAutomaticAssignment:dict kindOfClass:[self class] ToModel:obj WithNameDictionary:@{@"ids":@"id"} openRecursive:NO];
    
    return obj;
}

/**
 *  带改名字典的自动赋值，键值对为 新属性名:原属性名（即数据字典key值）
 *  @param dic    数据字典
 *  @param mClass 要赋值的对象的class,class可以是这个类本身，也可以是它的父类的，增加这个参数是考虑到对继承自父类的那部分的属性赋值
 *  @param model  要赋值的模型对象
 *  @param nameDic 改名字典
 *  @param open   是否开启递归赋值
 *  @return 成功返回model本身，传入参数有误返回nil
 */
+(NSObject *)ModelAttributeAutomaticAssignment:(NSDictionary *)dic  kindOfClass:(Class)mClass ToModel:(NSObject *)model WithNameDictionary:(NSDictionary *)nameDic openRecursive:(BOOL)open{
    
    /**
     *  模型，字典，class不对都直接返回
     */
    if (!model || ![dic isKindOfClass:[NSDictionary class]] || ![model isKindOfClass:mClass]) {
        return nil;
    }
    NSDictionary * attrDic = [self property:mClass];//获取模型的属性字典
    
    NSArray * nameArr = [attrDic allKeys];//取得所有属性名
    
    for (int i = 0;i < nameArr.count; i++) {//循环赋值
        NSString * key = nameArr[i];//模型属性名
        NSString * attrKey = key;   //数据字典属性名，默认和模型属性名相同
        if (nameDic) {              //如果改名字典中有相应的模型属性名，则修改数据字典属性名
            if (nameDic[key]) {
                attrKey = nameDic[key];
            }
        }
        
        //获得数据字典中attrKey对应的值的class，获得模型字典中key值对应的class
        Class dicObjectValue = [dic[attrKey] class];
        Class modelAttrValue = NSClassFromString(attrDic[key]);
        
        //针对JSON中的数据类型可以赋一个默认值
        if ([modelAttrValue isSubclassOfClass:[NSString class]] && ![model valueForKey:key]) {
            [model setValue:@"" forKey:key];
        }
        if ([modelAttrValue isSubclassOfClass:[NSNumber class]] && ![model valueForKey:key]) {
            [model setValue:@(NSNotFound) forKey:key];
        }
        if ([modelAttrValue isSubclassOfClass:[NSArray class]] && ![model valueForKey:key]) {
            [model setValue:[NSArray array] forKey:key];
        }
        if ([modelAttrValue isSubclassOfClass:[NSDictionary class]] && ![model valueForKey:key]) {
            [model setValue:[NSDictionary dictionary] forKey:key];
        }
        
        
        if (dicObjectValue == nil) {        //如果数据字典中没有取到值，直接忽略
            continue;
        }
        
        //如果数据字典属性类型和模型属性类型相同，直接赋值
        if ([dicObjectValue isSubclassOfClass:modelAttrValue]) {
            [model setValue:dic[attrKey] forKey:key];
            
        }else{   //NSString 和 NSNumber 可以互相转换
            
            if ([dicObjectValue isSubclassOfClass:[NSString class]] &&
                [modelAttrValue isSubclassOfClass:[NSNumber class]])
            {
                NSNumber * number = [[[NSNumberFormatter alloc] init] numberFromString:dic[attrKey]];
                
                if (number) {
                    [model setValue:number forKey:key];
                }
                
            }else if ([dicObjectValue isSubclassOfClass:[NSNumber class]] && [modelAttrValue isSubclassOfClass:[NSString class]]){
                
                NSString * string = [NSString stringWithFormat:@"%@",dic[attrKey]];
                [model setValue:string forKey:key];
                
            }
            
            /**
             *  如果递归赋值开启，数据字典当前值的类型为字典，则
             *  ! 默认模型的当前属性为子模型  创建一个子对象并递归赋值
             *  ! 如果模型中当前属性不是相应的子模型，可能导致崩溃
             *  @param open 是否开启递归赋值
             *
             *
             */
            
            else if (open && [dicObjectValue isSubclassOfClass:[NSDictionary class]])
            {
                NSObject * obj = [[modelAttrValue alloc] init];
                if (obj) {
                    [self ModelAttributeAutomaticAssignment:dic[attrKey]  kindOfClass:[obj class] ToModel:obj WithNameDictionary:nameDic openRecursive:YES];
                    [model setValue:obj forKey:key];
                }
            }
        }
    }
    
    return model;
}

+(NSDictionary *)property:(Class)mclass{
    
    NSMutableDictionary * attrDic = [NSMutableDictionary new];
    
    unsigned int count = 0;
    //取得当前class的所有属性数组
    objc_property_t * proArr = class_copyPropertyList(mclass, &count);
    
    //获得属性名和类型
    for (int i = 0; i < count; i++) {
        
        objc_property_t property = proArr[i];
        
        NSString * name = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];//获得属性名
        
        NSString * valueStr = [NSString stringWithCString:property_getAttributes(property) encoding:NSUTF8StringEncoding];//获得类型字符串
        
        valueStr = [self valueString:valueStr];//通过解析方法转换类型字符串，获得类型名称
        
        [attrDic setObject:valueStr forKey:name];
        
    }
    
    free(proArr);
    
    return attrDic;
}

+(NSString *)valueString:(NSString *)valueStr{
    
    NSString * temp = [valueStr componentsSeparatedByString:@","][0];
    
    if ([temp rangeOfString:@"@"].location != NSNotFound) {
        
        if (temp.length == 2) {
            return @"NSObject";
        }
        
        if (temp.length < 4) {
            return @" ";
        }
        
        temp = [[temp substringToIndex:temp.length - 1] substringFromIndex:3];
        
        return temp;
        
    }else if(temp.length == 2){
        
        return @"NSNumber";
        
    }
    
    return @" ";
    
}

@end
