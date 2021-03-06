//
//  MoviesViewController.swift
//  MovieViewer
//
//  Created by Davis Wamola on 3/31/17.
//  Copyright © 2017 Davis Wamola. All rights reserved.
//

import UIKit
import AFNetworking
import MBProgressHUD

class MoviesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var networkErrorView: UIView!
    @IBOutlet weak var networkErrorImageView: UIImageView!
    @IBOutlet weak var searchBarView: UISearchBar!

    var movies: [NSDictionary]?
    var unfilteredMovies: [NSDictionary] = []
    var movieTitles: [String] = []

    var api_key: String = "a07e22bc18f5cb106bfe4cc1f83ad8ed"
    var endpoint: String = "now_playing"

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        networkErrorImageView.image = UIImage(named: "error")
        networkErrorView.isHidden = true

        // Infinite Scrolling
        let tableFooterView: UIView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 50))
        let loadingView: UIActivityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        loadingView.startAnimating()
        loadingView.center = tableFooterView.center
        tableFooterView.addSubview(loadingView)
        self.tableView.tableFooterView = tableFooterView
        
        // Pull down refresh control
        let refreshControl = UIRefreshControl()
        
        refreshControl.addTarget(self, action: #selector(refreshControlAction(_:)), for: UIControlEvents.valueChanged)
        // add refresh control to table view
        tableView.insertSubview(refreshControl, at: 0)

        // Customize Navigation Bar
        self.navigationItem.title = "iFlicks"
        if let navigationBar = navigationController?.navigationBar {
            navigationBar.tintColor = UIColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 0.8)
            
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.blue.withAlphaComponent(0.5)
            shadow.shadowOffset = CGSize(width: 2, height: 2)
            shadow.shadowBlurRadius = 4;
            navigationBar.titleTextAttributes = [
                NSFontAttributeName : UIFont.boldSystemFont(ofSize: 22),
                NSForegroundColorAttributeName : UIColor(red: 0.5, green: 0.15, blue: 0.15, alpha: 0.8),
                NSShadowAttributeName : shadow
            ]
        }

        // Add search bar
        searchBarView.delegate = self

        getMoviesData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let cell = sender as! UITableViewCell
        let indexPath = tableView.indexPath(for: cell)
        let movie = movies![indexPath!.row]
        
        // Get the new view controller using
        let detailViewController = segue.destination as!DetailViewController
        // Pass the selected object to the new view controller.
        detailViewController.movie = movie
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let movies = movies {
            return movies.count
        } else {
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier:
            "MovieCell") as! MovieCell
        let movie = movies![indexPath.row]
        
        if let title = movie.value(forKeyPath:"title") as? String {
            cell.titleLabel.text = title
        }
        
        if let overview = movie.value(forKeyPath:"overview") as? String {
            cell.overviewLabel.text = overview
        }
        
        if let posterPath = movie.value(forKeyPath:"poster_path") as? String {
            let baseUrl = "https://image.tmdb.org/t/p/w342"
            
            if let imageUrl = URL(string: baseUrl + posterPath) {
                let imageRequest = NSURLRequest(url: imageUrl)

                cell.photoView.setImageWith(
                    imageRequest as URLRequest,
                    placeholderImage: nil,
                    success: { (imageRequest, imageResponse, image) -> Void in
                        // imageResponse will be nil if the image is cached
                        if imageResponse != nil {
                            //print("Image was NOT cached, fade in image")
                            cell.photoView.alpha = 0.0
                            cell.photoView.image = image
                            UIView.animate(withDuration: 0.3, animations: { () -> Void in
                                cell.photoView.alpha = 1.0
                            })
                        } else {
                            //print("Image was cached so just update the image")
                            cell.photoView.image = image
                        }
                },
                    failure: { (imageRequest, imageResponse, error) -> Void in
                        // do something for the failure condition
                        self.networkErrorView.isHidden = false
                })
            }
        }

        // No color when the user selects cell
        cell.selectionStyle = .none

        return cell
    }    

    func getMoviesData() {
        let url = URL(string:"https://api.themoviedb.org/3/movie/\(endpoint)?api_key=\(api_key)")
        let request = URLRequest(url: url!)
        let session = URLSession(
            configuration: URLSessionConfiguration.default,
            delegate:nil,
            delegateQueue:OperationQueue.main
        )
        
        // Display HUD right before the request is made
        MBProgressHUD.showAdded(to: self.view, animated: true)

        let task : URLSessionDataTask = session.dataTask(
            with: request as URLRequest,
            completionHandler: { (data, response, error) in
                if let data = data {
                    if let responseDictionary = try! JSONSerialization.jsonObject(
                        with: data, options:[]) as? NSDictionary {
                        
                        // Hide HUD once the network request comes back (must be done on main UI thread)
                        MBProgressHUD.hide(for: self.view, animated: true)

                        // This is where you will store the returned array of movies in your movies property
                        self.movies = responseDictionary["results"] as? [NSDictionary]
                        for movie in self.movies! {
                            self.movieTitles.append(movie["title"] as! String)
                        }
                        self.unfilteredMovies = self.movies!

                        self.tableView.reloadData()
                    }
                } else {
                    self.networkErrorView.isHidden = false
                }
        });
        task.resume()
    }

    func refreshControlAction(_ refreshControl: UIRefreshControl) {
        getMoviesData()
        // Tell the refreshControl to stop spinning
        refreshControl.endRefreshing()
    }

    func searchBar(_ searchBarView: UISearchBar, textDidChange searchText: String){
        let filteredString = movieTitles.filter { (item: String) -> Bool in
            let matchString = item.lowercased().range(of: searchText.lowercased())
            return matchString != nil ? true : false
        }

        var filteredMovies: [NSDictionary] = []

        for movie in self.movies! {
            for title in filteredString {
                if title.contains (movie["title"] as! String) && !(filteredMovies.contains(movie)){
                    filteredMovies.append(movie)
                }
            }
        }

        if (!searchText.isEmpty){
            self.movies = filteredMovies
        } else{
            // Get all the movies if the search bar is empty
            self.movies = self.unfilteredMovies
        }

        self.tableView.reloadData()
    }
}
