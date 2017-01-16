//
//  SettingsViewController.swift
//  zai
//
//  Created by 渡部郷太 on 1/11/17.
//  Copyright © 2017 watanabe kyota. All rights reserved.
//

import Foundation
import UIKit


class SettingView {
    init(section: Int) {
        self.section = section
    }
    
    func getCell(tableView: UITableView, indexPath: IndexPath) -> UITableViewCell { return UITableViewCell() }
    
    func shouldHighlightRowAt(row: Int) -> Bool { return false}
    
    var settingName: String { get { return "" } }
    var settingCount: Int { get { return 0 } }
    let section: Int
}

class SettingsViewController : UITableViewController, UserAccountSettingDelegate, ZaifSettingViewDelegate, AppSettingViewDelegate, ChangeUpdateIntervalDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.barTintColor = Color.keyColor
        
        self.tableView.tableFooterView = UIView()
        
        self.tableView.register(UINib(nibName: "ReadOnlySettingCell", bundle: nil), forCellReuseIdentifier: "readOnlySettingCell")
        self.tableView.register(UINib(nibName: "VariableSettingCell", bundle: nil), forCellReuseIdentifier: "variableSettingCell")
        self.tableView.register(UINib(nibName: "ValueActionSettingCell", bundle: nil), forCellReuseIdentifier: "valueActionSettingCell")
        
        let account = getAccount()!
        self.userSetting = UserAccountSettingView(account: account, section: self.settings.count)
        self.userSetting?.delegate = self
        self.settings.append(self.userSetting!)
        
        if let zaif = account.getExchange(exchangeName: "Zaif") {
            self.zaifSetting = ZaifSettingView(zaifExchange: zaif as! ZaifExchange, section: self.settings.count)
            self.zaifSetting?.delegate = self
            self.settings.append(self.zaifSetting!)
        }
        
        self.appSetting = AppSettingView(config: getConfig(), section: self.settings.count)
        self.appSetting?.delegate = self
        self.settings.append(self.appSetting!)
    }
    
    public override func numberOfSections(in tableView: UITableView) -> Int {
        return self.settings.count
    }
    
    public override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 0.0
        } else {
            return 28.0
        }
    }
    
    public override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel(frame: CGRect(x: 20.0, y: 0.0, width: 100.0, height: 28.0))
        label.textColor = UIColor.gray
        label.font = label.font.withSize(14.0)
        label.text = self.settings[section].settingName
        
        let view = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 28.0))
        view.backgroundColor = UIColor.groupTableViewBackground
        view.addSubview(label)
        return view
    }
    
    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < self.settings.count else {
            return 0
        }
        return self.settings[section].settingCount
    }
    
    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        guard section < self.settings.count else {
            return tableView.dequeueReusableCell(withIdentifier: "readOnlySettingCell", for: indexPath) as! ReadOnlySettingCell
        }
        return self.settings[section].getCell(tableView: tableView, indexPath: indexPath)
    }
    
    public override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let section = indexPath.section
        guard section < self.settings.count else {
            return false
        }
        return self.settings[section].shouldHighlightRowAt(row: indexPath.row)
    }
    
    // UserAccountSettingDelegate
    func loggedOut(userId: String) {
        let storyboard: UIStoryboard = self.storyboard!
        let login = storyboard.instantiateViewController(withIdentifier: "loginViewController") as! LoginViewController
        self.present(login, animated: true, completion: nil)
    }
    
    func changePassword() {
        self.performSegue(withIdentifier: "changePasswordSegue", sender: nil)
    }
    
    // ZaifSettingViewDelegate
    func changeApiKeys() {
        self.performSegue(withIdentifier: "changeZaifApiKeysSegue", sender: nil)
    }
    
    // AppSettingViewDelegate
    func changeUpdateInterval() {
        self.performSegue(withIdentifier: "changeUpdateIntervalSegue", sender: nil)
    }
    
    // ChangeUpdateIntervalDelegate
    func saved(interval: UpdateInterval) {
        self.appSetting?.updateAutoUpdateInterval(tableView: self.tableView, interval: interval)
    }
    
    @IBAction func pushBackButton(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func unwindToSettings(_ segue: UIStoryboardSegue) {}
    
    @IBAction func passwordSaved(_ segue: UIStoryboardSegue) {}
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let ident = segue.identifier else {
            return
        }
        switch ident {
        case "changeZaifApiKeysSegue":
            let dst = segue.destination as! ChangeZaifApiKeyController
            dst.zaifExchange = self.zaifSetting?.zaifExchange
        case "changeUpdateIntervalSegue":
            let dst = segue.destination as! ChangeUpdateIntervalController
            dst.config = self.appSetting?.config
            dst.delegate = self
        default: break
        }
    }
    
    var userSetting: UserAccountSettingView?
    var zaifSetting: ZaifSettingView?
    var appSetting: AppSettingView?
    var settings = [SettingView]()
}