//
//  ConnectionDelegate.swift
//  Connections
//
//  Created by Matthew Whyte on 2019/03/27.
//  Copyright © 2019 Matthew Whyte ("MattJWhyte"). All rights reserved.
//

import Foundation

/*
 * The ConnectionDelegate protocol handles all intermediate updates From the Connection class.
 * Implementing methods can produce more control over the connection process.
 */
protocol ConnectionDelegate
{
    //Check for whether or not connection delegate should have verbose reporting
    var verboseConnection : Bool { get set }
    //Called when connection is lost
    func didLose(connection: Connection)
    //Called when connection is regained
    func didRegain(connection: Connection)
    //Called when connection began
    func didStartLoading(for connection: Connection)
    //Called when loading connection stopped
    func didStopLoading(for connection: Connection)
    //Called when connection encounters error
    func didEncounter(error: ConnectionError, forConnection connection: Connection)
    //Check for whether server response is valid according to various uses
    func response(isValid data: Data, forProcess process: ConnectionProcess, onConnection connection: Connection) -> Bool
}

/*
 * Extension of Delegate which provides basic implementations of all methods
 * with a verbose reporting option (by checking verboseConnection)
 */
extension ConnectionDelegate
{
    func didLose(connection: Connection) {
        if verboseConnection {
            print("\(connection) : Did Lose Connection")
        }
    }
    
    func didRegain(connection: Connection) {
        if verboseConnection {
            print("\(connection) : Did Regain Connection")
        }
    }
    
    func didStartLoading(for connection: Connection) {
        if verboseConnection {
            print("\(connection) : Did Start Loading")
        }
    }
    
    func didStopLoading(for connection: Connection) {
        if verboseConnection {
            print("\(connection) : Did Stop Loading")
        }
    }
    
    func didEncounter(error: ConnectionError, forConnection connection: Connection) {
        if verboseConnection {
            print("\(connection) : Did Encounter Error - \(error.description)")
        }
    }
    
    func response(isValid data: Data, forProcess process: ConnectionProcess, onConnection connection: Connection) -> Bool {
        if verboseConnection {
            print("\(connection) : Response is Valid")
        }
        return true
    }
}
