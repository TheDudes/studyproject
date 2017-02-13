package studyproject.gui.mainWindow;

import java.net.URL;
import java.util.ArrayList;
import java.util.ResourceBundle;

import javax.inject.Inject;

import javafx.fxml.FXML;
import javafx.fxml.Initializable;
import javafx.scene.Node;
import javafx.scene.Scene;
import javafx.scene.layout.AnchorPane;
import javafx.stage.Modality;
import javafx.stage.Stage;
import studyproject.App;
import studyproject.API.Lvl.Low.Broadcast;
import studyproject.gui.mainWindow.filesTree.FilesTreeView;
import studyproject.gui.mainWindow.logArea.LogAreaView;
import studyproject.gui.mainWindow.tasksList.TasksListView;
import studyproject.gui.mainWindow.topMenu.TopMenuView;
import studyproject.gui.mainWindow.usersList.UsersListView;
import studyproject.gui.selectedInterface.SelectedInterfaceView;

public class MainWindowPresenter implements Initializable {

	@FXML
	AnchorPane usersListAnchor;
	@FXML
	AnchorPane filesTreeAnchor;
	@FXML
	AnchorPane tasksListAnchor;
	@FXML
	AnchorPane topMenuAnchor;
	@FXML
	AnchorPane logAreaAnchor;
	@Inject
	MainWindowModel mainWindowModel;

	@Override
	public void initialize(URL location, ResourceBundle resources) {
		FilesTreeView filesTreeView = new FilesTreeView();
		filesTreeAnchor.getChildren().addAll(filesTreeView.getView());
		
		LogAreaView logAreaView = new LogAreaView();
		logAreaAnchor.getChildren().addAll(logAreaView.getView());
		
		UsersListView usersListView = new UsersListView();
		usersListAnchor.getChildren().addAll(usersListView.getView());
		
		TasksListView tasksListView = new TasksListView();
		tasksListAnchor.getChildren().addAll(tasksListView.getView());
		
		TopMenuView topMenuView = new TopMenuView();
		topMenuAnchor.getChildren().addAll(topMenuView.getView());
		
		setAllAnchorPoints(filesTreeView.getView(), 0.0);
		setAllAnchorPoints(logAreaView.getView(), 0.0);
		setAllAnchorPoints(usersListView.getView(), 0.0);
		setAllAnchorPoints(tasksListView.getView(), 0.0);
		setAllAnchorPoints(topMenuView.getView(), 0.0);
	}
	
	private void setAllAnchorPoints(Node child, double value) {
		AnchorPane.setBottomAnchor(child, value);
		AnchorPane.setTopAnchor(child, value);
		AnchorPane.setLeftAnchor(child, value);
		AnchorPane.setRightAnchor(child, value);
	}
	
	public void loadInterface() {
		ArrayList<String> interfaces = new ArrayList<String>();
		Broadcast.getNetworkAddresses(interfaces);
		String interf = (String) App.properties.get("defaultInterface");
		if ((interf == null) || interf.isEmpty() || (!interfaces.contains(interf))) {
			SelectedInterfaceView selectedInterfaceView = new SelectedInterfaceView();
			Stage interfaceStage = new Stage();
			interfaceStage.setMinWidth(300);
			interfaceStage.setMinHeight(200);
			interfaceStage.setTitle("Startup...");
			interfaceStage.setScene(new Scene(selectedInterfaceView.getView()));
			interfaceStage.initModality(Modality.APPLICATION_MODAL);
			interfaceStage.showAndWait();
		} else {
			mainWindowModel.getLodds().startUp(interf, (String) App.properties.get("userName"));
		}
	}

}
