//
//  Connection.swift
//  Connections
//
//  Created by Matthew Whyte on 2019/03/27.
//  Copyright © 2019 Matthew Whyte ("MattJWhyte"). All rights reserved.
//

import Foundation
import UIKit

/*
 * The Connection class is the centre of the framework.
 * All requests are coordinated and managed through instances of this class.
 */
class Connection
{
    //Default URL path of server to make requests to
    public var rootUrlPath: String
    //Default data that is always sent when making requests
    public var defaultPostParameters: [String:String]
    //Connection delegate
    public var delegate: ConnectionDelegate?
    //Suspended connection process
    private var suspendedProcess: ConnectionProcess?
    
    //Error handling
    private(set) var hasLostConnection = false
    
    //Shared instance of Connection object
    public static var shared: Connection?
    
    /*
     * Initialises Connection object
     * @param path : Bool - flag for if connection is lost
     * @param parameters : Bool - flag for if connection is lost
     * @param delegate : Bool - flag for if connection is lost
     */
    init(withDefaultPath path: String, parameters: [String:String], delegate: ConnectionDelegate?) {
        self.rootUrlPath = path
        self.defaultPostParameters = parameters
        self.delegate = delegate
    }

    //Copy current connection instance with new properties (optional)
    func copy(newDelegate: ConnectionDelegate? = nil, newUrlPath: String? = nil, newParameters: [String:String]? = nil) -> Connection {
        return Connection(withDefaultPath: newUrlPath ?? rootUrlPath, parameters: newParameters ?? defaultPostParameters, delegate: newDelegate ?? delegate)
    }
    
    /*
     * Updates connection error status
     * @param status : Bool - flag for if connection is lost
     */
    private func updateError(status: Bool) {
        //Check if status has changed
        if status != hasLostConnection {
            //Update connection status
            hasLostConnection = status
            if status { //Connection Lost
                delegate?.didLose(connection: self)
            }
            else { //Connection regained
                delegate?.didRegain(connection: self)
            }
        }
    }
    
    /*
     * Continue any suspended process when connection is regained
     */
    private func continueSuspendedProcess() {
        //Check if there is a suspended process
        if var proc = self.suspendedProcess {
            //Remove process
            self.suspendedProcess = nil
            //Refresh parameters for process's request
            refreshDefaultParameters(for: &proc)
            //Fetch data
            fetchDataFrom(process: proc)
        }
    }
    
    /*
     * Refreshes parameters of process with default parameters
     * @param process : ConnectionProcess - process to update
     */
    func refreshDefaultParameters(for process: inout ConnectionProcess) {
        //Get copy of process's request
        let req = (process.request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        //Get request parameters
        let param = String(data: req.httpBody!, encoding: .utf8)!
        //Split into component key-value pairs
        let pairs = param.split(separator: "&")
        //Create dictionary for parameters
        var dic = [String:String]()
        //Iterate through pairs
        for p in pairs {
            //Split into key and value
            let comp = p.split(separator: "=")
            //Add parameter pair to dictionary
            dic[String(comp[0])] = String(comp[1])
        }
        //Iterate through key-values in default parameters
        for (key, value) in self.defaultPostParameters {
            //Assign to dictionary
            dic[key] = value
        }
        //Encode parameter dictionary and add to request body
        req.httpBody = encodeURL(parameters: dic).data(using: String.Encoding.utf8)
        //Update request property of inout process
        process.request = req as URLRequest
    }
    
    /*
     * Notifies delegate when connection began loading
     */
    func didStartLoading() {
        self.delegate?.didStartLoading(for: self)
    }
    
    /*
     * Notifies delegate when connection stopped loading
     */
    func didStopLoading() {
        self.delegate?.didStopLoading(for: self)
    }
    
    /*
     * Returns request for connection to file path on server
     * @param filePath : String - location of file on server
     * @param param : String? - optional POST parameters for request
     */
    func requestFor(filePath: String, withParameters param: String? = nil) -> URLRequest {
        //Create request for url with file path and default URL path
        return requestFor(url: completeUrl(for: filePath), withParameters: param)
    }
    
    /*
     * Returns request for connection to URL
     * @param url : URL - url to make request from
     * @param param : String? - optional POST parameters for request
     */
    func requestFor(url: URL, withParameters param: String? = nil) -> URLRequest {
        //Encode default parameters into a compliant POST format and include any other parametters
        let post = "\(encodeURL(parameters: defaultPostParameters))\(param != nil ? "&\(param!)" : "")"
        //Convert POST String into Data for request body
        let postData = post.data(using: String.Encoding.utf8)!
        //Get length of POST Data
        let postLength = "\(postData.count)"
        //Create request for URL
        let request = NSMutableURLRequest(url: url)
        //Set HTTP Method to POST
        request.httpMethod = "POST"
        //Set POST body length for request
        request.setValue(postLength, forHTTPHeaderField: "Content-Length")
        //Set content type for body of request
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        //Assign POST Data to request body
        request.httpBody = postData
        //Return request cast as URLRequest
        return request as URLRequest
    }
    
    /*
     * Fetches data from a ConnectionProcess
     * @param process : ConnectionProcess - process to extract request and handler from
     */
    func fetchDataFrom(process: ConnectionProcess) {
        //Call method for fetching data from request with completion handler
        fetchDataFrom(request: process.request, completionHandler: process.handler)
    }
    
    /*
     * Fetches data from request and processes it using handler
     * @param request : URLRequest - request to fetch data from
     * @param completionHandler - void closure to handle response data
     */
    func fetchDataFrom(request: URLRequest, completionHandler: @escaping (Data) -> Void) {
        //Create process for connection in the event that connection is lost
        let proc = ConnectionProcess(request: request, handler: completionHandler)
        //Create URL session to make connection
        let task = URLSession.shared.dataTask(with: request) {
            data, response, error in
            //Begin call to delegate to notify it that loading has stopped
            self.didStopLoading()
            //Check if there was an error
            if error != nil { //Error present
                self.updateError(status: true)
                //Wait 5 seconds before repeating the connection
                DispatchQueue.main.asyncAfter(deadline: .now()+5) {
                    //Call same method again
                    self.fetchDataFrom(request: request, completionHandler: completionHandler)
                }
            }
            else { //No Error
                self.updateError(status: false)
                //Check if server response is valid according to delegate
                //Always true if delegate is absent
                if self.delegate?.response(isValid: data!, forProcess: proc, onConnection: self) ?? true {
                    //Call completion handler with response data
                    completionHandler(data!)
                }
            }
        }
        //Commence task
        task.resume()
    }
    
    /*
     * Fetches data from file path on server
     * @param filePath : String - location of file at default URL path
     * @param param : String? - optional POST parameters to include
     * @param completionHandler - void closure to handle response data
     */
    func fetchDataFrom(filePath: String, withParameters param: String?, completionHandler: @escaping (Data) -> Void) {
        //Call overloaded method with URL parameter
        fetchDataFrom(url: completeUrl(for: filePath), withParameters: param, completionHandler: completionHandler)
    }
    
    /*
     * Fetches data from URL
     * @param url : URL - url of file to fetch data from
     * @param param : String? - optional POST parameters to include
     * @param completionHandler - void closure to handle response data
     */
    func fetchDataFrom(url: URL, withParameters param: String?, completionHandler: @escaping (Data) -> Void) {
        //Create request for URL with optional parameters
        let req = requestFor(url: url, withParameters: param)
        //Call overloaded method with URLRequest parameter
        fetchDataFrom(request: req, completionHandler: completionHandler)
    }
    
    /*
     * Parses JSON data from URLRequest and returns it as a dictionary
     * @param request : URLRequest - request to fetch data from
     * @param completionHandler - void closure to handle decoded dictionary
     */
    func parseJsonFrom(request: URLRequest, completionHandler: @escaping ([String:String]) -> Void) {
        //Call method to fetch data from request
        fetchDataFrom(request: request) {
            //Closure to handle data
            data in
            //Check if data can be decoded as JSON and cast as String dictionary
            if let dict = Json.decode(json: data) as? [String:String] {
                //Handle response
                completionHandler(dict)
            }
            else {
                //Notify delegate that a JSON error was encountered
                self.delegate?.didEncounter(error: .InvalidJson, forConnection: self)
            }
        }
    }
    
    /*
     * Parses JSON data from file path and returns it as a dictionary
     * @param filePath : String -  location of file at default URL path
     * @param param : String? - optional POST parameters to include
     * @param completionHandler - void closure to handle decoded dictionary
     */
    func parseJsonFrom(filePath: String, withParameters param: String? = nil, completionHandler: @escaping ([String:String]) -> Void) {
        //Create request for file path and parameters
        let req = requestFor(filePath: filePath, withParameters: param)
        //Call method to parse JSON from request with handler
        parseJsonFrom(request: req, completionHandler: completionHandler)
    }
    
    /*
     * Parses JSON data from URL and returns it as a dictionary
     * @param url : URL -  URL of file to fetch JSON from
     * @param param : String? - optional POST parameters to include
     * @param completionHandler - void closure to handle decoded dictionary
     */
    func parseJsonFrom(url: URL, withParameters param: String? = nil, completionHandler: @escaping ([String:String]) -> Void) {
        //Create request for url and parameters
        let req = requestFor(url: url, withParameters: param)
        //Call method to parse JSON from request with handler
        parseJsonFrom(request: req, completionHandler: completionHandler)
    }
    
    /*
     * Parses JSON data from URLRequest and returns it as an array of dictionaries
     * @param request : URLRequest - request to fetch data from
     * @param completionHandler - void closure to handle decoded dictionary array
     */
    func parseJsonArrayFrom(request: URLRequest, completionHandler: @escaping ([[String:String]]) -> Void) {
        //Call method to fetch data from request
        self.fetchDataFrom(request: request) {
            //Closure to handle data
            data in
            //Check if data can be decoded as JSON array and cast as String dictionary array
            if let dict = Json.decode(json: data) as? [[String:String]] {
                //Handle response
                completionHandler(dict)
            }
            else {
                //Notify delegate that a JSON error was encountered
                self.delegate?.didEncounter(error: .InvalidJson, forConnection: self)
            }
        }
    }
    
    /*
     * Parses JSON array from file path and returns it as an array of dictionaries
     * @param filePath : String -  location of file at default URL path
     * @param param : String? - optional POST parameters to include
     * @param completionHandler - void closure to handle decoded dictionary array
     */
    func parseJsonArrayFrom(filePath: String, withParameters param: String? = nil, completionHandler: @escaping ([[String:String]]) -> Void) {
        //Create request for file path and parameters
        let req = requestFor(filePath: filePath, withParameters: param)
        //Call method to parse JSON array from request with handler
        parseJsonArrayFrom(request: req, completionHandler: completionHandler)
    }
    
    /*
     * Parses JSON array from URL and returns it as an array of dictionaries
     * @param url : URL -  URL of file to fetch JSON from
     * @param param : String? - optional POST parameters to include
     * @param completionHandler - void closure to handle decoded dictionary array
     */
    func parseJsonArrayFrom(url: URL, withParameters param: String? = nil, completionHandler: @escaping ([[String:String]]) -> Void) {
        //Create request for URL and parameters
        let req = requestFor(url: url, withParameters: param)
        //Call method to parse JSON array from request with handler
        parseJsonArrayFrom(request: req, completionHandler: completionHandler)
    }
    
    /*
     * Returns request for uploading Base64 images to a given URL
     *
     * @param images : [UIImage] - images to upload
     * @param url : URL - url of file to upload image to
     * @param param : [String:String] - optional POST parameters for request
     * @param imagePrefix : String - POST variable name prefix for each image
     *     Default case is "image"
     *
     * NOTE: Image data is available on server-side through POST Data in the following format:
     *     [IMAGE_PREFIX][IMAGE_NUMBER]
     *     Example: 3 images to upload and imagePrefix = img
     *         Data is available at $_POST[img1], $_POST[img2], and $_POST[img3] (PHP)
     *
     * NOTE: Number of images is available on server-side through POST with var name "image_count"
     */
    func base64UploadRequestFor(images: [UIImage], toUrl url: URL, withParameters param: [String: String] = [:], imagePrefix: String = "image") -> URLRequest {
        //Assign parameters to var to be manipulated
        var parameters = param
        //Iterate through each image to be uploaded
        for i in 1...images.count {
            //Create image data to be sent
            let imgData = images[i-1].jpegData(compressionQuality: 1)
            //Encode image data as base64 String
            let str = imgData?.base64EncodedString(options:.lineLength64Characters)
            //Assign image String to 'image' key in parameters
            parameters["\(imagePrefix)\(i)"] = str
        }
        //Write number of images to POST data
        parameters["image_count"] = "\(images.count)"
        //Return a request for the given file path with parameters, including base64 image
        return requestFor(url: url, withParameters: encodeURL(parameters: parameters))
    }
    
    /*
     * Returns request for uploading Base64 image to a given file path on server
     *
     * @param images : [UIImage] - images to upload
     * @param filePath : String - location of file at default URL path
     * @param param : [String:String] - optional POST parameters for request
     * @param imagePrefix : String - POST variable name prefix for each image
     *     Default case is "image"
     *
     * NOTE: See Above method comment for how to access image data on server
     */
    func base64UploadRequestFor(images: [UIImage], toFilePath filePath: String, withParameters param: [String: String] = [:], imagePrefix: String = "image") -> URLRequest {
        //Call method to get request from URL overloaded method
        return base64UploadRequestFor(images: images, toUrl: completeUrl(for: filePath), withParameters: param, imagePrefix: imagePrefix)
    }
    
    /*
     * Multipart/form-data request for uploading images to a given URL
     *
     * @param images : [UIImage] - images to upload
     * @param url : URL - url of file to upload image to
     * @param param : [String:String] - optional POST parameters for request
     * @param imagePrefix : String - POST variable name prefix for each image
     *     Default case is "image"
     *
     * NOTE: Image data is available on server-side through FILE UPLOAD Data in the following name format:
     *     [IMAGE_PREFIX][IMAGE_NUMBER]
     *     Example: 3 images to upload and imagePrefix = img
     *         Data is available at $_FILES[img1], $_FILES[img2], and $_FILES[img3] (PHP)
     *
     * NOTE: Number of images is available on server-side through POST with var name "image_count"
     */
    func uploadRequestFor(images: [UIImage], toUrl url: URL, withParameters param: [String:String] = [:], imagePrefix: String = "image") -> URLRequest {
        //Create mutable request from url
        let request = NSMutableURLRequest(url: url)
        //Set HTTP method to POST
        request.httpMethod = "POST"
        //Create Boundary String
        let boundary = createBoundaryString()
        //Set content type for HTTP body
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        //Create image data array
        var imageDataArray = [Data]()
        //Iterate through images
        for image in images {
            //Add data of each image to data array
            imageDataArray.append(image.jpegData(compressionQuality: 1)!)
        }
        //Create mutable var for parameters
        var parameters = param
        //Iterate through key-value pairs in default parameters
        for (key, value) in defaultPostParameters {
            //Check if key is empty
            if param[key] == nil {
                //Write value to default parameter key
                parameters[key] = value
            }
        }
        //Add additional POST variable for image count
        parameters["image_count"] = "\(images.count)"
        //Create HTTP body with parameters and image data
        request.httpBody = createBodyWith(parameters: parameters, filePathKey: imagePrefix, imageDataArray: imageDataArray, boundary: boundary)
        //Return request
        return request as URLRequest
    }
    
    /*
     * Multipart/form-data request for uploading images to a given URL
     *
     * @param images : [UIImage] - images to upload
     * @param filePath : String - location of file at default URL path
     * @param param : [String:String] - optional POST parameters for request
     * @param imagePrefix : String - POST variable name prefix for each image
     *     Default case is "image"
     *
     * NOTE: See Above method comment for how to access image data on server
     */
    func uploadRequestFor(images: [UIImage], toFilePath filePath: String, withParameters param: [String:String], imagePrefix: String = "image") -> URLRequest {
        //Call method to get request from URL overloaded method
        return uploadRequestFor(images: images, toUrl: completeUrl(for: filePath), withParameters: param, imagePrefix: imagePrefix)
    }
    
    /*
     * Combines file path with root URL into a complete URL for requests
     */
    private func completeUrl(for filePath: String) -> URL {
        return URL(string: "\(rootUrlPath)\(filePath)")!
    }
    
    /*
     * Creates boundary String for multipart/form-data
     */
    private func createBoundaryString() -> String {
        return "Boundary-\(UUID().uuidString)"
    }
    
    /*
     Encodes POST parameters and image data into a format compatible with multipart/form-data
     */
    private func createBodyWith(parameters: [String:String], filePathKey: String, imageDataArray: [Data], boundary: String) -> Data {
        //Create body data
        var body = Data()
        //Iterate through key-value pairs in parameters
        for (key, value) in parameters {
            //Encode pair in the right format
            body.append(string:"--\(boundary)\r\n")
            body.append(string:"Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append(string:"\(value)\r\n")
        }
        //File name for each file
        let filePrefix = "file"
        
        let mimetype = "image/jpg"
        //Create counter for images
        var count = 1
        //Iterate through image data
        for imageData in imageDataArray {
            //Encode image data
            body.append(string:"--\(boundary)\r\n")
            body.append(string:"Content-Disposition: form-data; name=\"\(filePathKey)\(count)\"; filename=\"\(filePrefix)\(count).jpg\"\r\n")
            body.append(string:"Content-Type: \(mimetype)\r\n\r\n")
            body.append(imageData)
            body.append(string:"\r\n")
            //Increment counter
            count += 1
        }
        //Append one last boundary
        body.append(string:"--\(boundary)--\r\n")
        //Return data
        return body as Data
    }
    
    /*
     * Encode dictionary of parameters into url-compliant String
     */
    func encodeURL(parameters: [String:String]) -> String {
        //Create String array to store parameters
        var params = [String]()
        //Iterate through enumerated array of parameter dictionary
        for (_, param) in parameters.enumerated() {
            //Append the key-value pairs to the String array
            params.append("\(param.key)=\(param.value)")
        }
        //Return the components of parameter array joined with ampersands
        return params.joined(separator: "&")
    }
}

/*
 * Extension for appending a String to a Data object
 */
extension Data
{
    mutating func append(string: String) {
        //Create Data representation of String
        let data = string.data(
            using: String.Encoding.utf8,
            allowLossyConversion: true)
        //Append to original data
        append(data!)
    }
}
