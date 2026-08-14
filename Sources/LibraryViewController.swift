import UIKit

/// The reading queue. Shows what is on the device versus what is only on the
/// laptop, because that distinction is the whole offline story and hiding it
/// would mean discovering a missing paper on a train.
final class LibraryViewController: UITableViewController {

    private var papers: [Paper] { return Store.shared.papers }
    private var downloading = Set<String>()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Reading"
        tableView.rowHeight = 68
        tableView.tableFooterView = UIView()

        // Pull to refresh, not a blocking sync. The library is usable from
        // local storage the entire time it is refreshing.
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Sync", style: .plain, target: self, action: #selector(syncNow))

        refresh()
    }

    // MARK: - Sync

    @objc private func refresh() {
        SyncClient.shared.fetchLibrary { [weak self] papers in
            guard let self = self else { return }
            self.refreshControl?.endRefreshing()
            self.tableView.reloadData()
            // Offline is normal, not an error. The queue on disk still works,
            // so say nothing and carry on.
            _ = papers
        }
    }

    @objc private func syncNow() {
        SyncClient.shared.flush { [weak self] ok in
            self?.navigationItem.rightBarButtonItem?.title = ok ? "Synced" : "Offline"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self?.navigationItem.rightBarButtonItem?.title = "Sync"
            }
        }
    }

    // MARK: - Table

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        return papers.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "paper")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "paper")
        let paper = papers[indexPath.row]

        cell.textLabel?.text = paper.title
        cell.textLabel?.numberOfLines = 2
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15)

        let count = Store.shared.annotations(for: paper.key).count
        var parts: [String] = []
        if downloading.contains(paper.key) {
            parts.append("downloading…")
        } else if Store.shared.isDownloaded(paper) {
            parts.append("offline")
        } else {
            parts.append("on laptop")
        }
        if count > 0 { parts.append("\(count) annotation\(count == 1 ? "" : "s")") }
        if let minutes = paper.repMinutes { parts.append("\(minutes) min rep") }

        cell.detailTextLabel?.text = parts.joined(separator: " · ")
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12)
        cell.detailTextLabel?.textColor = UIColor(white: 0.5, alpha: 1)
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let paper = papers[indexPath.row]

        if Store.shared.isDownloaded(paper) {
            open(paper)
            return
        }

        // Downloading is explicit, so you always know what you are carrying
        // before you lose signal.
        downloading.insert(paper.key)
        tableView.reloadRows(at: [indexPath], with: .none)
        SyncClient.shared.download(paper) { [weak self] ok, reason in
            guard let self = self else { return }
            self.downloading.remove(paper.key)
            self.tableView.reloadRows(at: [indexPath], with: .none)
            if ok {
                self.open(paper)
            } else {
                self.reportFailure(paper: paper, reason: reason)
            }
        }
    }

    /// Say why. A download that fails silently looks identical to one that
    /// hung, and leaves nothing to debug from -- which is exactly what the
    /// double-encoded URL bug looked like on the device.
    private func reportFailure(paper: Paper, reason: String?) {
        let alert = UIAlertController(
            title: "Couldn't download",
            message: (reason ?? "Unknown error") + "\n\n" + paper.filename,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func open(_ paper: Paper) {
        navigationController?.pushViewController(
            ReaderViewController(paper: paper), animated: true)
    }
}
