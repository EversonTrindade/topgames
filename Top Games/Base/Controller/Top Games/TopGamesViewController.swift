//
//  TopGamesViewController.swift
//  Top Games
//
//  Created by Everson Trindade on 08/05/18.
//  Copyright © 2018 Everson Trindade. All rights reserved.
//

import UIKit

fileprivate struct CellIdentifier {
    static let gameId = "TopGamesViewCell"
}

class TopGamesViewController: UIViewController, LoadContent, GameCellDelegate {
    
    // MARK: Properties
    lazy var viewModel: TopGamesViewModelPresentable = TopGamesViewModel(delegate: self)
    let refresher = UIRefreshControl()
    var searchController: UISearchController!

    // MARK: IBOutlet
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var searchBarViewPlacehold: UIView!
    
    // MARK: ViewController life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        addRefresh()
        addSearchBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        tabBarController?.navigationItem.title = "Games"
        loadContent()
    }
    
    // MARK: Prepare for segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let detailViewcontroller = segue.destination as? DetailViewController, let dto = sender as? GameDetailDTO {
                detailViewcontroller.fill(with: dto)
            }
        }
    }
    
    // MARK: Functions
    func checkConnectionAndGetGames() {
        if Reachability.isConnectedToNetwork() {
            showLoader()
            viewModel.getGames()
            viewModel.getFavorites()
        } else {
            showDefaultAlert(message: "No connetion!", completeBlock: nil)
            dismissLoader()
            viewModel.eraseData()
            reloadCollectionView()
        }
    }
    
    private func addRefresh() {
        collectionView?.alwaysBounceVertical = true
        refresher.tintColor = .black
        refresher.addTarget(self, action: #selector(refresh), for: .valueChanged)
        collectionView?.addSubview(refresher)
    }
    
    @objc func refresh() {
        if Reachability.isConnectedToNetwork() {
            viewModel.refresh()
        } else {
            showDefaultAlert(message: "No connetion!", completeBlock: nil)
            viewModel.eraseData()
            reloadCollectionView()
        }
        
        reloadCollectionView()
    }
    
    func addSearchBar() {
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.searchBar.sizeToFit()
        searchController.searchBar.placeholder = "Search Game"
        searchController.dimsBackgroundDuringPresentation = false
        searchBarViewPlacehold.addSubview(searchController.searchBar)
    }
    
    // MARK: LoadContent
    func loadContent() {
        checkConnectionAndGetGames()
    }
    
    func didLoadContent(error: String?) {
        dismissLoader()
        if let _ = error {
            showDefaultAlert(message: "Can not load games. Try later!", completeBlock: nil)
        } else {
           reloadCollectionView()
        }
        DispatchQueue.main.async {
            self.refresher.endRefreshing()
        }
    }
    
    func didLoadImage(identifier: Int) {
        DispatchQueue.main.async {
            guard let collection = self.collectionView else {
                return
            }
            for cell in collection.visibleCells {
                if let gameCell = cell as? TopGamesViewCell, gameCell.identifier == identifier {
                    gameCell.setImage(with: self.viewModel.imageFromCache(identifier: identifier))
                }
            }
        }
    }
    
    func reloadCollectionView() {
        DispatchQueue.main.async {
            self.refresher.endRefreshing()
            self.collectionView.reloadData()
        }
    }
    
    func didTapOnSearchToReload() {
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.dismissLoader()
        }
    }
    
    // MARK: GameCellDelegate
    func didFavorite(with id: Int, shouldFavorite: Bool, imageData: Data?) {
        viewModel.didFavorite(with: id, shouldFavorite: shouldFavorite, imageData: imageData)
    }
}

// MARK: UIColleectionViewDelegate/DataSource
extension TopGamesViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return viewModel.numberOfSections()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.numberOfItemsInSection()
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellIdentifier.gameId, for: indexPath) as? TopGamesViewCell else {
            return UICollectionViewCell()
        }
        cell.delegate = self
        cell.fillCell(dto: viewModel.gameDTO(row: indexPath.row))
        if indexPath.row == viewModel.numberOfItemsInSection() - 1 && viewModel.canLoad {
            checkConnectionAndGetGames()
        }
        dismissLoader()
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let gameCell = cell as? TopGamesViewCell {
            gameCell.fillCell(dto: viewModel.gameDTO(row: indexPath.row))
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        performSegue(withIdentifier: "showDetail", sender: viewModel.getGameDetailDTO(row: indexPath.row))
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return viewModel.sizeForItems(with: view.frame.size.width, height: view.frame.size.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return viewModel.minimumInteritemSpacingForSectionAt()
    }
}

//MARK: Search Bar
extension TopGamesViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        if searchController.isActive {
            viewModel.updateSearchResults(for: searchController)
            dismissLoader()
            refresher.removeFromSuperview()
        } else {
            collectionView.addSubview(refresher)
            viewModel.setSearchBarActive()
        }
        didTapOnSearchToReload()
    }
}
