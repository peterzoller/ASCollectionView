// ASCollectionView. Created by Apptek Studios 2019

import DifferenceKit
import UIKit

@available(iOS 13.0, *)
class ASDiffableDataSourceTableView<SectionID: Hashable>: ASDiffableDataSource<SectionID>, UITableViewDataSource
{
	/// The type of closure providing the cell.
	public typealias Snapshot = ASDiffableDataSourceSnapshot<SectionID>
	public typealias CellProvider = (UITableView, IndexPath, ASCollectionViewItemUniqueID) -> ASTableViewCell?

	private weak var tableView: UITableView?
	private let cellProvider: CellProvider

	var onDelete: ((_ indexPath: IndexPath) -> Void)?
	var onMove: ((_ source: IndexPath, _ destination: IndexPath) -> Void)?

	public init(tableView: UITableView, cellProvider: @escaping CellProvider)
	{
		self.tableView = tableView
		self.cellProvider = cellProvider
		super.init()

		tableView.dataSource = self
	}

	/// The default animation to updating the views.
	public var defaultRowAnimation: UITableView.RowAnimation = .automatic

	private var firstLoad: Bool = true
	private var canRefreshSizes: Bool = false

	func applySnapshot(_ newSnapshot: Snapshot, animated: Bool = true, completion: (() -> Void)? = nil)
	{
		guard let tableView = tableView else { return }

		firstLoad = false

		let changeset = StagedChangeset(source: currentSnapshot.sections, target: newSnapshot.sections)
		let shouldDisableAnimation = firstLoad || !animated

		canRefreshSizes = false
		CATransaction.begin()
		if shouldDisableAnimation
		{
			CATransaction.setDisableActions(true)
		}
		CATransaction.setCompletionBlock { [weak self] in
			self?.canRefreshSizes = true
			completion?()
		}
		tableView.reload(using: changeset, with: shouldDisableAnimation ? .none : .automatic) { newSections in
			self.currentSnapshot = .init(sections: newSections)
		}
		CATransaction.commit()
	}

	func updateCellSizes(animated: Bool = true)
	{
		guard let tableView = tableView, canRefreshSizes, !tableView.visibleCells.isEmpty else { return }
		CATransaction.begin()
		if !animated
		{
			CATransaction.setDisableActions(true)
		}
		tableView.performBatchUpdates(nil, completion: nil)

		CATransaction.commit()
	}

	func didDisappear()
	{
		canRefreshSizes = false
	}

	func numberOfSections(in tableView: UITableView) -> Int
	{
		currentSnapshot.sections.count
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
	{
		currentSnapshot.sections[section].elements.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
	{
		let itemIdentifier = identifier(at: indexPath)
		guard let cell = cellProvider(tableView, indexPath, itemIdentifier) else
		{
			fatalError("ASTableView dataSource returned a nil cell for row at index path: \(indexPath), tableView: \(tableView), itemIdentifier: \(itemIdentifier)")
		}
		return cell
	}

	func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool
	{
		true
	}

	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath)
	{
		guard let onDelete = onDelete else { return }
		var deleteSnapshot = currentSnapshot
		deleteSnapshot.removeItems(fromSectionIndex: indexPath.section, atOffsets: [indexPath.row])
		applySnapshot(deleteSnapshot, animated: true, completion: nil)
		onDelete(indexPath)
	}

	func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool
	{
		onMove != nil
	}

	func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath)
	{
		guard let onMove = onMove else { return }
		var moveSnapshot = currentSnapshot
		moveSnapshot.moveItem(fromIndexPath: sourceIndexPath, toIndexPath: destinationIndexPath)
		applySnapshot(moveSnapshot, animated: true, completion: nil)
		onMove(sourceIndexPath, destinationIndexPath)
	}
}
