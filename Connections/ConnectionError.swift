//
//  ConnectionError.swift
//  Connections
//
//  Created by Matthew Whyte on 2019/03/27.
//  Copyright © 2019 Matthew Whyte ("MattJWhyte"). All rights reserved.
//

import Foundation

/*
 * The ConnectionError enum classifies errors which Connection objects may encounter.
 */
enum ConnectionError
{
    //Error Cases
    case Unexpected, InvalidJson
    
    /*
     * Returns String description of case
     */
    var description : String {
        switch self {
        case .InvalidJson:
            return "Invalid JSON"
        default:
            return "Unexpected Error"
        }
    }
}
