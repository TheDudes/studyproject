package studyproject.gui.mainWindow.filesTree;

import java.net.URL;
import java.util.ResourceBundle;
import java.util.Vector;
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Level;
import java.util.logging.Logger;

import javax.inject.Inject;

import javafx.beans.binding.Bindings;
import javafx.beans.binding.BooleanBinding;
import javafx.beans.value.ChangeListener;
import javafx.beans.value.ObservableValue;
import javafx.collections.FXCollections;
import javafx.collections.ObservableList;
import javafx.collections.transformation.FilteredList;
import javafx.fxml.FXML;
import javafx.fxml.Initializable;
import javafx.scene.control.*;
import javafx.scene.image.Image;
import javafx.scene.image.ImageView;
import studyproject.App;
import studyproject.API.Errors.ErrorFactory;
import studyproject.API.Lvl.Mid.Core.FileCoreInfo;
import studyproject.API.Lvl.Mid.Core.UserInfo;
import studyproject.gui.Core.Utils;
import studyproject.gui.mainWindow.MainWindowModel;
import studyproject.gui.mainWindow.tasksList.TasksListModel;
import studyproject.gui.mainWindow.userList.UserListModel;
import studyproject.logging.LogKey;

public class FilesTreePresenter implements Initializable {

	@FXML
	TreeView<FileCoreInfo> filesTreeView;
	@FXML
	TextField filesTreeSearch;
	@FXML
	MenuItem reloadTreeCM;
	@Inject
	UserListModel userListModel;
	@Inject
	MainWindowModel mainWindowModel;
	@Inject
	TasksListModel tasksListModel;
	@FXML
	Button downloadButton;
	@FXML
	Button filesTreeRefresh;

	private final TreeItem<FileCoreInfo> root = new TreeItem<FileCoreInfo>();
	private FilteredList<TreeItem<FileCoreInfo>> filteredFileList;
	private Image fileImage;
	private Image refreshImage;

	@Override
	public void initialize(URL location, ResourceBundle resources) {
		filesTreeView.getSelectionModel().setSelectionMode(SelectionMode.MULTIPLE);
		filesTreeView.setShowRoot(false);
		filesTreeView.setRoot(root);
		BooleanBinding disableIfNoSelection = Bindings.isNull(filesTreeView.getSelectionModel().selectedItemProperty());
		downloadButton.disableProperty().bind(disableIfNoSelection);
		downloadButton.setOnAction(e -> downloadPressed());
		userListModel.getSelectedUser().addListener(new ChangeListener<UserInfo>() {
			@Override
			public void changed(ObservableValue<? extends UserInfo> observable, UserInfo oldValue, UserInfo newValue) {
				if (observable == null) {
					root.getChildren().clear();
					return;
				}
				createTree(newValue);
			}
		});
		reloadTreeCM.setOnAction(e -> createTree(userListModel.getSelectedUser().get()));
		filesTreeRefresh.setOnAction(e -> createTree(userListModel.getSelectedUser().get()));
		filesTreeSearch.textProperty().addListener(e -> {
			filesTreeSearchChanged();
		});
		filteredFileList = new FilteredList<TreeItem<FileCoreInfo>>(root.getChildren(), p -> true);

		// style button
		if (Boolean.valueOf(App.properties.getProperty("icons"))) {
			fileImage = new Image(getClass().getResourceAsStream(App.ICON_PATH + "file.png"), 16, 16, true, true);
			refreshImage = new Image(getClass().getResourceAsStream(App.ICON_PATH + "reload.png"), 16, 16, true, true);
			filesTreeRefresh.setGraphic(new ImageView(refreshImage));
			filesTreeRefresh.setText(null);
		}

	}

	public void createTree(UserInfo userInfo) {
		if (userInfo == null)
			return;
		root.getChildren().clear();
		String[] subPaths = null;
		FileCoreInfo infoToAdd = null;
		int startIndex = 0;
		for (String path : userInfo.getPathToFileInfo().keySet()) {
			infoToAdd = userInfo.getPathToFileInfo().get(path);
			subPaths = path.split("/");
			if (subPaths[0].isEmpty())
				startIndex = 1;
			addTreeItem(infoToAdd, subPaths, startIndex, root);
		}
	}

	private void addTreeItem(FileCoreInfo infoToAdd, String[] subPaths, int index, TreeItem<FileCoreInfo> parent) {
		TreeItem<FileCoreInfo> folderToAdd = null;

		for (TreeItem<FileCoreInfo> item : parent.getChildren()) {
			if (subPaths[index].equals(item.getValue().getFileName())) {
				addTreeItem(infoToAdd, subPaths, ++index, item);
				return;
				// size = addTreeItem(infoToAdd, subPaths, ++index, item);
				// item.getValue().increment size

			}
		}
		if (index == subPaths.length - 1) {
			// ADD THE FILE
			TreeItem<FileCoreInfo> treeItem = new TreeItem<FileCoreInfo>(infoToAdd);
			// if icons property set style with icon
			if (Boolean.valueOf(App.properties.getProperty("icons"))) {
				ImageView imageView = new ImageView();
				imageView.setPreserveRatio(true);
				imageView.setFitHeight(18);
				imageView.setFitWidth(18);
				imageView.setImage(fileImage);
				treeItem.setGraphic(new ImageView(fileImage));
				parent.getChildren().add(treeItem);
			} else {
				parent.getChildren().add(treeItem);
			}
			// return child.size();
		} else

		{
			// ADD new folder and recur with it
			String folderPath;
			if (parent.equals(root)) {
				// if it is the base first folder to add
				folderPath = "/" + subPaths[index];
			} else {
				// if the root is already set
				folderPath = parent.getValue().getFilePath() + "/" + subPaths[index];
			}
			folderToAdd = new TreeItem<FileCoreInfo>(new FileCoreInfo(subPaths[index], folderPath));

			parent.getChildren().add(folderToAdd);
			addTreeItem(infoToAdd, subPaths, ++index, folderToAdd);
		}
	}

	/**
	 * Download the selected files and folder from the filesTree. When a folder
	 * is selected, download all children. If there are some of the children
	 * selected as well, only download the selected children and none of the
	 * other, unselected children
	 */
	private void downloadPressed() {
		ObservableList<TreeItem<FileCoreInfo>> itemsList = filesTreeView.getSelectionModel().getSelectedItems();
		String absolutePath = Utils.getChoosenDirPath("Choose folder to save files in");
		if (absolutePath == null)
			return;
		absolutePath = absolutePath.replace("\\", "/");
		if (absolutePath.equals(null)) {
			Logger.getGlobal().log(ErrorFactory.build(Level.INFO, LogKey.info, "No folder chosen. Download aborted."));
			return;
		} else if (absolutePath.endsWith("/")) {
			absolutePath = absolutePath.substring(0, absolutePath.length() - 1);
		}

		for (TreeItem<FileCoreInfo> treeItem : itemsList) {
			FileCoreInfo fileCoreInfo = treeItem.getValue();
			if (fileCoreInfo.isFolder()) {
				// If children of this folder are selected as well, ignore this
				// item
				boolean continueForEachLoop = false;
				for (TreeItem<FileCoreInfo> listItem : itemsList) {
					if (listItem.getValue().getFilePath().contains(fileCoreInfo.getFilePath())
							&& !(fileCoreInfo.equals(listItem.getValue()))) {
						continueForEachLoop = true;
						break;
					}
				}
				if (continueForEachLoop) {
					continue;
				}

				// If none of the folder children is selected, download it
				Vector<FileCoreInfo> fileCoreInfoVector = new Vector<FileCoreInfo>();
				fileCoreInfoVector = findChildrenItems(treeItem, fileCoreInfoVector);
				mainWindowModel.getLodds().getMultipleFiles(fileCoreInfoVector, userListModel.getSelectedUser().get(),
						absolutePath, fileCoreInfo.getFileName());

			} else {
				// item is a file, download it
				mainWindowModel.getLodds().getFile(userListModel.getSelectedUser().get(), fileCoreInfo.getChecksum(),
						absolutePath + fileCoreInfo.getFilePath());
			}
		}
		return;
	}

	private Vector<FileCoreInfo> findChildrenItems(TreeItem<FileCoreInfo> treeItem, Vector<FileCoreInfo> vector) {
		for (TreeItem<FileCoreInfo> childrenItem : treeItem.getChildren()) {
			if (childrenItem.getValue().isFolder()) {
				vector = findChildrenItems(childrenItem, vector);
			} else {
				vector.add(childrenItem.getValue());
			}
		}
		return vector;
	}

	private void filesTreeSearchChanged() {
		if (userListModel.getSelectedUser().getValue() == null) {
			return;
		}
		if (filesTreeSearch.textProperty().get().isEmpty()) {
			// No searchString. Show full files tree
			filteredFileList.setPredicate(p -> true);
			createTree(userListModel.getSelectedUser().get());
		} else {
			// searchString entered
			int index;
			FileCoreInfo fileCoreInfo;
			String[] subPaths;
			ConcurrentHashMap<String, FileCoreInfo> userFileMap = userListModel.getSelectedUser().get()
					.getPathToFileInfo();
			javafx.collections.ObservableList<String> fileCoreInfoList;

			fileCoreInfoList = javafx.collections.FXCollections
					.synchronizedObservableList(FXCollections.observableArrayList());
			fileCoreInfoList.addAll(userFileMap.keySet());

			FilteredList<String> filteredPathList = fileCoreInfoList
					.filtered(p -> p.toLowerCase().contains(filesTreeSearch.textProperty().get().toLowerCase()));

			root.getChildren().clear();
			for (String path : filteredPathList) {
				fileCoreInfo = userFileMap.get(path);
				index = 0;
				subPaths = path.split("/");
				if (subPaths[0].isEmpty())
					index = 1;
				addTreeItem(fileCoreInfo, subPaths, index, root);

			}
		}
	}
}
