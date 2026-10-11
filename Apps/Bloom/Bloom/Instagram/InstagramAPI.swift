//
//  InstagramAPI.swift
//  Bloom
//
//  Created by Francesco on 04/05/26.
//

import Foundation

struct InstagramAPIError: Error, LocalizedError {
    let message: String
    
    var errorDescription: String? {
        message
    }
}
