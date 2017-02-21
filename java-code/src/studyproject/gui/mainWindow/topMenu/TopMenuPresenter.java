package studyproject.gui.mainWindow.topMenu;

import java.io.File;
import java.io.IOException;
import java.net.URL;
import java.security.NoSuchAlgorithmException;
import java.util.ResourceBundle;
import java.util.logging.Level;
import java.util.logging.Logger;

import javax.inject.Inject;

import javafx.concurrent.Task;
import javafx.fxml.FXML;
import javafx.fxml.Initializable;
import javafx.scene.Scene;
import javafx.scene.control.Menu;
import javafx.scene.control.MenuItem;
import javafx.stage.DirectoryChooser;
import javafx.stage.Modality;
import javafx.stage.Stage;
import studyproject.API.Errors.ErrorFactory;
import studyproject.App;
import studyproject.API.Core.File.FileInfo;
import studyproject.gui.Core.Utils;
import studyproject.gui.mainWindow.MainWindowModel;
import studyproject.gui.mainWindow.usersList.UsersListModel;
import studyproject.gui.settingsWindow.SettingsWindowView;
import studyproject.logging.LogKey;

public class TopMenuPresenter implements Initializable {

	@FXML
	Menu fileMenu;
	@FXML
	MenuItem settingsItem;
	@FXML
	MenuItem shareFolder;
	@FXML
	MenuItem sendFileToUser;
	@Inject
	MainWindowModel mainWindowModel;
	@Inject
	UsersListModel usersListModel;

	private Logger logger;

	@Override
	public void initialize(URL location, ResourceBundle resources) {
		logger = Logger.getGlobal();
		fileMenu.setOnShowing(e -> fileMenuPressed());

		settingsItem.setOnAction(e -> settingsItemPressed());
		shareFolder.setOnAction(e -> shareFolderPressed());
		sendFileToUser.setOnAction(e -> sendFileToUser());

	}

	private void fileMenuPressed() {
		if (usersListModel.getSelectedUser().get() == null) {
			sendFileToUser.setDisable(true);
		} else {
			sendFileToUser.setDisable(false);
		}
	}

	private void shareFolderPressed() {
		Stage stage = new Stage();
		DirectoryChooser directoryChooser = new DirectoryChooser();
		File chosenFolder = directoryChooser.showDialog(stage);
		if (chosenFolder == null)
			return;

		Task<Void> shareFolderTask = new Task<Void>() {
			@Override
			protected Void call() throws Exception {
				mainWindowModel.getLodds().shareFolder(chosenFolder.getAbsolutePath());
				return null;
			}
		};
		stage.hide();

		Thread thread = new Thread(shareFolderTask);
		thread.setDaemon(true);
		thread.start();
	}

	private void settingsItemPressed() {
		Stage stage = new Stage();
		SettingsWindowView settingsView = new SettingsWindowView();
		stage.setScene(new Scene(settingsView.getView()));
		stage.initModality(Modality.APPLICATION_MODAL);
		stage.show();
	}

	/**
	 * Send one file to the selected User from the usersList
	 */
	private void sendFileToUser() {
		String userName = usersListModel.getSelectedUser().get().getUserName();
		long timeout = Long.parseLong((String) App.properties.get("getPermissionTimeout")) * 1000;
		File file = Utils.getChoosenFile("Select File to share");
		FileInfo fileInfo;
		try {
			fileInfo = new FileInfo(file.getPath(), file.getPath());
			mainWindowModel.getLodds().sendFileWP(userName, timeout, fileInfo);
		} catch (NoSuchAlgorithmException e) {
			logger.log(ErrorFactory.build(Level.SEVERE, LogKey.error, "NoSuchAlgorithmException thrown: ", e));
		} catch (IOException e) {
			logger.log(ErrorFactory.build(Level.SEVERE, LogKey.error, "IOException thrown: ", e));
		}
	}

}