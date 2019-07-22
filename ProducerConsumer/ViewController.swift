//
//  ViewController.swift
//  ProducerConsumer
//
//  Created by Kai Oelfke on 19.07.19.
//  Copyright © 2019 Kai Oelfke. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

	// The most important thing is the serial queue for producing and consuming.
	// Otherwise the thread execution could happen in an order, where too many cells
	// are consumed and producedCells becomes negative resulting in errors with
	// UITableView.numberOfRowsInSection
	private let serialQueue = DispatchQueue(label: "de.kaioelfke.ProducerConsumer.SerialProductionConsumptionQueue")
	private let timerQueue = DispatchQueue(label: "de.kaioelfke.ProducerConsumer.TimerQueue", attributes: .concurrent)
	private var gcdTimers: [DispatchSourceTimer] = []
	private var producedCells = 0
	private var tableViewReloadsInIntervals = false
	private let tableViewReloadTimerLimit = 100
	private let tableViewReloadInterval = 1
	private let productionInterval = 3
	private let consumptionInterval = 4
	
	@IBOutlet weak var tableView: UITableView!
	
	typealias TimerHandler = (() -> Void)?
	
	@IBAction func addProducer(_ sender: Any) {
		addTimer(with: produce, intervalInSeconds: productionInterval)
	}
	
	@IBAction func addConsumer(_ sender: Any) {
		addTimer(with: consume, intervalInSeconds: consumptionInterval)
	}
	
	private func addTimer(with handler: TimerHandler, intervalInSeconds: Int) {
		let timer = DispatchSource.makeTimerSource(queue: timerQueue)
		timer.schedule(deadline: .now() + .seconds(intervalInSeconds),
					   repeating: .seconds(intervalInSeconds),
					   leeway: .milliseconds(intervalInSeconds * 100))
		timer.setEventHandler(handler: handler)
		gcdTimers.append(timer)
		timer.resume()
		if gcdTimers.count > tableViewReloadTimerLimit && !tableViewReloadsInIntervals {
			configureTableViewUpdateTimer()
		}
	}

	private func configureTableViewUpdateTimer() {
		// Serial queue for the unlikely case that addConsumer and addProducer is called concurrently,
		// which should not happen as long as it is only triggered on the main thread,
		// by the user pressing the corresponding buttons.
		serialQueue.async {
			guard !self.tableViewReloadsInIntervals else { return }
			self.tableViewReloadsInIntervals = true
			print("Switched")
			let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
			let interval = Int(self.tableViewReloadInterval * 100)
			let leeway = Int(self.tableViewReloadInterval * 10)
			timer.schedule(deadline: .now(), repeating: .milliseconds(interval), leeway: .milliseconds(leeway))
			DispatchQueue.main.async {
				UIView.setAnimationsEnabled(false)
			}
			timer.setEventHandler(handler: {
				self.tableView.reloadData()
			})
			self.gcdTimers.append(timer)
			timer.resume()
		}
	}
	
	private func produce() {
		serialQueue.async {
			if self.producedCells < Int.max {
				self.producedCells += 1
				self.updateTableView()
			}
		}
	}
	
	private func consume() {
		serialQueue.async {
			if self.producedCells > 0 {
				self.producedCells -= 1
				self.updateTableView()
			}
		}
		
	}
	
	private func updateTableView() {
		if !tableViewReloadsInIntervals {
			DispatchQueue.main.async {
				self.tableView.reloadData()
			}
		}
	}
}

extension ViewController: UITableViewDataSource {
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return producedCells
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "CellReuseIdentifier")!
		cell.layer.shouldRasterize = true
		cell.layer.rasterizationScale = UIScreen.main.scale
		return cell
	}
	
	
}


