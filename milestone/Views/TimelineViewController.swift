//
//  TimelineViewController.swift
//  milestone
//
//  Created by Kent Waxman on 11/9/21.
//

import UIKit
import SwiftUI
import FirebaseAuth
import Firebase

//This allows us to communicate back to the Container View
protocol TimelineViewControllerDelegate: AnyObject {
    func didTapSideMenuButton()
    func didTapNewProjectButton()
}

class TimelineViewController: UITableViewController {
    static var timelineCellIdentifier = "timelineCell"
    
    //This is a weak variable because it prevents memory leaks
    weak var delegate: TimelineViewControllerDelegate?
    
    var scheduler = Scheduler()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Timeline"
    
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        self.tableView.register(TimelineCell.self, forCellReuseIdentifier: TimelineViewController.timelineCellIdentifier)
        //Based from afformentioned youtube video on side bar (normally We do this in the story board view)
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gearshape"),
                                                           style: .done,
                                                           target: self,
                                                           action: #selector(didTapSideMenuButton))
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"),
                                                           style: .done,
                                                           target: self,
                                                           action: #selector(refreshTimeline))

    }
    
    override func viewDidAppear(_ animated: Bool) {
        refreshTimeline()
    }
    
    @objc func didTapSideMenuButton() {
        delegate?.didTapSideMenuButton()
    }
    
    @objc func didTapNewProjectButton() {
        delegate?.didTapNewProjectButton()
    }
    
    //Can we make another function that doesn't always refresh the timeline upon a segue?
    @IBAction func unwindToTimelineViewController(segue: UIStoryboardSegue) {
//        print("revealing timeline again...")
        refreshTimeline()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scheduler.getProjectDictCount()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TimelineViewController.timelineCellIdentifier, for: indexPath) as? TimelineCell else {
            fatalError("Unable to dequeue Timelinecell")
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    //setting up the footer for the "Add New Project" button
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 50))
        footerView.backgroundColor = UIColor.clear
        let button = UIButton(frame: CGRect(x: footerView.center.x, y: 0, width: 50, height: 50))
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.addTarget(self, action: #selector(didTapNewProjectButton), for: .touchUpInside)
        footerView.addSubview(button)
        return footerView
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 50
    }
    
    @objc func refreshTimeline() {
        scheduler.queryMilestones()
        self.tableView.reloadData()
    }
}

class TimelineCell: UITableViewCell {
    @IBOutlet weak var milestoneLabel: UILabel?
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}

struct SchedulerStruct {
    //Dictionary key is userID
    var projectDict: [String: (Any, [Milestone])] = [:] //a project name (first string) has its own due date (Any) and multiple Milestones inside of it ([Milestone])
}

class Scheduler {
    var db = Firestore.firestore()
    let userID = Auth.auth().currentUser?.uid
    
    var schedulerStruct: SchedulerStruct
    
    init() {
        self.schedulerStruct = SchedulerStruct()
    }
        
    func queryMilestones() {
        print("Scheduler running...")
        db.collection(userID!).getDocuments(completion: { [self](querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                for document in querySnapshot!.documents {
                    let projectDueDate = document.data()["projectDueDate"] ?? Date()
                    var milestones = [Milestone]()
                    guard let unparsedMilestones = document.data()["milestones"] as? [[String:Any]] else {
                        print("No milestones were found in \(document.documentID)")
                        return
                    }
                    for milestone in unparsedMilestones {
                        let currentMilestone = Milestone(
                            milestoneName: milestone["milestoneName"] as! String,
                            milestoneDueDate: (milestone["milestoneDueDate"] as! Timestamp).dateValue(),
                            milestoneDifficultyRating: milestone["milestoneDifficultyRating"] as! Int)
                        milestones.append(currentMilestone)
                    }
                    schedulerStruct.projectDict[document.documentID] = (projectDueDate, milestones)
                }
                print("Projects Queried:", schedulerStruct.projectDict) //for some reason, the projectDueDate doesn't show up as a "date" datatype but is just fine in Firebase... weird
            }
        })
    }
    
    //helper methods
    func getProjectDictCount() -> Int {
        print(schedulerStruct.projectDict.count)
        return schedulerStruct.projectDict.count
    }
    
    //returns the sorted milestones from the projectDict (CURRENTLY NO SORTING IS DONE)
    func sortMilestones() -> [Milestone] {
        var sortedMilestones: [Milestone] = []
        for (_, value) in schedulerStruct.projectDict {
            sortedMilestones.append(contentsOf: value.1)
        }
        return sortedMilestones
    }
}
