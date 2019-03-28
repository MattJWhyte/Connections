//
//  Json.swift
//  Connections
//
//  Created by Matthew Whyte on 2019/03/27.
//  Copyright © 2019 Matthew Whyte ("MattJWhyte"). All rights reserved.
//

import Foundation

/*
 * The Json class helps decode JSON String and Data objects
 * into more structured types.
 */
class Json
{
    /*
     * Decodes JSON data and returns it as Any to be cast to a relevant type
     */
    static func decode(json data: Data) -> Any? {
        do {
            //Decode JSON data
            let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions())
            return json
        }
        catch {
            //Return nil if an error was encountered
            return nil
        }
    }
    
    /*
     * Decodes JSON String and returns it as Any to be cast to a relevant type
     */
    static func decode(json string: String) -> Any? {
        //Convert String into data
        let data = string.data(using: String.Encoding.utf8)
        //Check if data exists
        if data != nil {
            //Call the decode function for JSON data
            return decode(json: data!)
        }
        //Return nil if data didn't exist
        return nil
    }
}
