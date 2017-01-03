//
//  ZaifApi.swift
//  zai
//
//  Created by 渡部郷太 on 1/1/17.
//  Copyright © 2017 watanabe kyota. All rights reserved.
//

import Foundation

import ZaifSwift
import SwiftyJSON


fileprivate extension ApiCurrencyPair {
    
    var zaifCurrencyPair: ZaifSwift.CurrencyPair {
        switch self {
        case .BTC_JPY:
            return ZaifSwift.CurrencyPair.BTC_JPY
        }
    }
}

fileprivate extension ZSErrorType {
    var apiError: ApiErrorType {
        switch self {
        case ZSErrorType.INFO_API_NO_PERMISSION:
            return ApiErrorType.NO_PERMISSION
        case ZSErrorType.NONCE_NOT_INCREMENTED:
            return ApiErrorType.NONCE_NOT_INCREMENTED
        default:
            return ApiErrorType.UNKNOWN_ERROR
        }
    }
}

fileprivate extension Order {
    
    func zaifOrder() -> ZaifSwift.Order? {
        let currencyPair = ApiCurrencyPair(rawValue: self.currencyPair)!
        switch currencyPair {
        case .BTC_JPY:
            let price = self.orderPrice == nil ? nil : Int(self.orderPrice!.doubleValue)
            if self.action == "bid" {
                return Trade.Buy.Btc.In.Jpy.createOrder(price, amount: self.orderAmount.doubleValue)
            } else if self.action == "ask" {
                return Trade.Buy.Btc.In.Jpy.createOrder(price, amount: self.orderAmount.doubleValue)
            } else {
                return nil
            }
        }
    }
}


class ZaifApi : Api {
    init(apiKey: String, secretKey: String, nonce: NonceProtocol?=nil) {
        self.api = PrivateApi(apiKey: apiKey, secretKey: secretKey, nonce: nonce)
    }
    
    func getPrice(currencyPair: ApiCurrencyPair, callback: @escaping (ApiError?, Double) -> Void) {
        PublicApi.lastPrice(currencyPair.zaifCurrencyPair) { (err, res) in
            if err != nil {
                callback(ApiError(errorType: err!.errorType.apiError, message: err!.message), 0.0)
            } else {
                guard let price = res?["last_price"].double else {
                    callback(ApiError(errorType: .UNKNOWN_ERROR), 0.0)
                    return
                }
                callback(nil, price)
            }
        }
    }
    
    func getBoard(currencyPair: ApiCurrencyPair, callback: @escaping (ApiError?, Board) -> Void) {
        PublicApi.depth(CurrencyPair.BTC_JPY) { (err, res) in
            let board = Board()
            if err != nil {
                callback(ApiError(errorType: err!.errorType.apiError, message: err!.message), board)
            } else {
                guard let asks = res?["asks"].array else {
                    callback(ApiError(errorType: .UNKNOWN_ERROR), board)
                    return
                }
                guard let bids = res?["bids"].array else {
                    callback(ApiError(errorType: .UNKNOWN_ERROR), board)
                    return
                }

                for ask in asks {
                    if let quote = ask.array {
                        board.addAsk(price: quote[0].doubleValue, amount: quote[1].doubleValue)
                    }
                }

                for bid in bids {
                    if let quote = bid.array {
                        board.addBid(price: quote[0].doubleValue, amount: quote[1].doubleValue)
                    }
                }
            }
        }
    }
    
    func getBalance(currencies: [ApiCurrency], callback: @escaping (ApiError?, [String:Double]) -> Void) {
        self.api.getInfo2() { (err, res) in
            var balance = [String:Double]()
            if err != nil {
                callback(ApiError(errorType: err!.errorType.apiError, message: err!.message), balance)
            } else {
                guard let deposits = res?["return"]["deposit"].dictionary else {
                    callback(ApiError(errorType: .UNKNOWN_ERROR), balance)
                    return
                }
                for currency in currencies {
                    if let deposit = deposits[currency.rawValue]?.double {
                        balance[currency.rawValue] = deposit
                    }
                }
                callback(nil, balance)
            }
        }
    }
    
    func getActiveOrders(currencyPair: ApiCurrencyPair, callback: @escaping (ApiError?, [String:ActiveOrder]) -> Void) {
        
        self.api.activeOrders(currencyPair.zaifCurrencyPair) { (err, res) in
            var activeOrders = [String:ActiveOrder]()
            if err != nil {
                callback(ApiError(errorType: err!.errorType.apiError, message: err!.message), activeOrders)
                return
            }
            
            guard let result = res?["success"].int else {
                callback(ApiError(errorType: .UNKNOWN_ERROR), activeOrders)
                return
            }
            if result != 1 {
                callback(ApiError(errorType: .UNKNOWN_ERROR), activeOrders)
                return
            }
            guard let orders = res?["return"].dictionary else {
                callback(ApiError(errorType: .UNKNOWN_ERROR), activeOrders)
                return
            }
            
            for (id, order) in orders {
                let action = order["action"].stringValue
                let price = order["price"].doubleValue
                let amount = order["amount"].doubleValue
                let timestamp = order["timestamp"].int64Value
                let activeOrder = ActiveOrder(id: id, action: action, currencyPair: currencyPair, price: price, amount: amount, timestamp: timestamp)
                activeOrders[id] = activeOrder
            }
            callback(nil, activeOrders)
        }
    }
    
    func trade(order: Order, callback: @escaping (ApiError?, String, Double) -> Void) {
        guard let zaifOrder = order.zaifOrder() else {
            callback(ApiError(errorType: .UNKNOWN_ERROR), "", 0.0)
            return
        }
        
        self.api.trade(zaifOrder, validate: false) { (err, res) in
            if err != nil {
                callback(ApiError(errorType: err!.errorType.apiError, message: err!.message), "", 0.0)
                return
            }
            guard let result = res?["success"].int else {
                callback(ApiError(errorType: .UNKNOWN_ERROR), "", 0.0)
                return
            }
            if result != 1 {
                callback(ApiError(errorType: .UNKNOWN_ERROR), "", 0.0)
                return
            }
            guard let ordered = res?["return"].dictionary else {
                callback(ApiError(errorType: .UNKNOWN_ERROR), "", 0.0)
                return
            }
            let orderId = ordered["order_id"]!.stringValue
            let orderedPrice = ordered["order_price"]!.doubleValue
            
            callback(nil, orderId, orderedPrice)
        }
    }
    
    func cancelOrder(order: ActiveOrder, callback: @escaping (_ err: ApiError?) -> Void) {
        self.api.cancelOrder(Int(order.id)!) { (err, res) in
            if err != nil {
                callback(ApiError(errorType: err!.errorType.apiError, message: err!.message))
                return
            }
            guard let result = res?["success"].int else {
                callback(ApiError(errorType: .UNKNOWN_ERROR))
                return
            }
            if result != 1 {
                callback(ApiError(errorType: .UNKNOWN_ERROR))
                return
            }
            callback(nil)
        }
    }
    
    func currencyPairs() -> [ApiCurrencyPair] {
        return [ApiCurrencyPair.BTC_JPY]
    }
    
    func currencies() -> [ApiCurrency] {
        return [ApiCurrency.JPY]
    }
    
    func orderUnit(currencyPair: ApiCurrencyPair) -> Double {
        return currencyPair.zaifCurrencyPair.orderUnit
    }
    
    var rawApi: Any { get { return self.api } }
    
    let api: PrivateApi
}