//
//  Browser.swift
//  wifilamp
//
//  Created by Jindrich Dolezy on 10/10/2017.
//  Copyright © 2017 The Cave. All rights reserved.
//

import Foundation

protocol BrowserDelegate: class {
    func browserStartedSearching(_ browser: Browser)
    func browser(_ browser: Browser, foundRecord record: BrowserRecord)
    func browser(_ browser: Browser, removedRecord record: BrowserRecord)
}

class Browser: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    let serviceType: String
    weak var delegate: BrowserDelegate?
    var records: [BrowserRecord] {
        return resolvedServices
    }
    
    private let browser: NetServiceBrowser
    private var servicesToResolve: [NetService] = []
    private var resolvedServices: [BrowserRecord] = []
    private var shouldRestartSearch: Bool = false
    private(set) var searching: Bool = false
    
    init(serviceType type: String = "_wifilamp._tcp.") {
        serviceType = type
        browser = NetServiceBrowser()
        
        super.init()
        
        browser.includesPeerToPeer = true
        browser.delegate = self
    }
    
    func startSearch() {
        if !searching {
            debugPrint("Starting search in local")
            browser.searchForServices(ofType: serviceType, inDomain: "local.")
        }
    }
    
    func stopSearch() {
        browser.stop()
    }
    
    func refresh() {
        if searching {
            shouldRestartSearch = true
            stopSearch()
        } else {
            startSearch()
        }
    }
    
    private func clearResults() {
        servicesToResolve.removeAll()
        resolvedServices.removeAll()
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        print("Error \(errorDict)")
        clearResults()
        searching = false
    }
    
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        debugPrint("Browser will search")
        clearResults()
        searching = true
        delegate?.browserStartedSearching(self)
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        debugPrint("Browser did stop search")
        clearResults()
        searching = false
        if shouldRestartSearch {
            shouldRestartSearch = false
            debugPrint("Browser restarting search")
            startSearch()
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        debugPrint("Browser did find service \(service.name) ")

        service.delegate = self
        service.stop()
        service.resolve(withTimeout: 10)
        servicesToResolve.append(service)
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        debugPrint("Browser did remove device \(service.name) ")

        servicesToResolve.removeFirst(element: service)
        if let record = resolvedServices.removeFirst(where: { $0.service == service }) {
            delegate?.browser(self, removedRecord: record)
        }
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        servicesToResolve.removeFirst(element: sender)
        if let record = BrowserRecord.from(service: sender) {
            debugPrint("Browser did resolve address \(record.toDevice().localNetworkUrl)")
            resolvedServices.append(record)
            delegate?.browser(self, foundRecord: record)
        }
        sender.stop()
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        debugPrint("Browser did not resolve address \(errorDict) ")
        servicesToResolve.removeFirst(element: sender)
    }
}

struct BrowserRecord {
    static let removedPrefix = "The Cave "
    
    let name: String
    let hostName: String
    let url: URL
    let chipId: String
    fileprivate let service: NetService
    
    static func from(service: NetService) -> BrowserRecord? {
        // swiftlint:disable:next force_https
        guard let data = service.txtRecordData(), let hostName = service.hostName, let url = URL(string: "http://\(hostName)") else {
            return nil
        }
        
        guard let chipIdData = NetService.dictionary(fromTXTRecord: data)["chipid"], let chipId = String(data: chipIdData, encoding: .utf8) else {
            return nil
        }
        
        var name = service.name
        if name.hasPrefix(removedPrefix) {
            name.removeFirst(removedPrefix.count)
        }
        
        return BrowserRecord(name: name, hostName: hostName, url: url, chipId: chipId, service: service)
    }
}

extension BrowserRecord: DeviceConvertible {
    func toDevice() -> Device {
        if hostName.hasPrefix("wifilamp") {
            return WiFiLamp(chipId: chipId, name: name, localNetworkUrl: url)
        } else {
            return UnknownDevice(chipId: chipId, name: name, localNetworkUrl: url)
        }
    }
}
