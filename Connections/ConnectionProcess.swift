//
//  ConnectionProcess.swift
//  Connections
//
//  Created by Matthew Whyte on 2019/03/27.
//  Copyright © 2019 Matthew Whyte ("MattJWhyte"). All rights reserved.
//

import Foundation

/*
 * The ConnectionProcess class serves to record current operations
 * being carried out by the Connection class.
 */
class ConnectionProcess
{
    //Request being used by process
    var request: URLRequest
    //Handler for completion of request
    var handler: (Data) -> Void
    
    /*
     * Initialiser which assigns parameters to instance variables
     */
    init(request: URLRequest, handler: @escaping (Data) -> Void) {
        self.request = request
        self.handler = handler
    }
}
