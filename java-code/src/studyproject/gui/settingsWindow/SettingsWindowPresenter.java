package studyproject.gui.settingsWindow;

import java.io.*;
import java.net.URL;
import java.util.ArrayList;
import java.util.Map.Entry;
import java.util.ResourceBundle;
import java.util.logging.Level;
import java.util.logging.Logger;

import javafx.collections.FXCollections;
import javafx.collections.ObservableList;
import javafx.fxml.FXML;
import javafx.fxml.Initializable;
import javafx.scene.Node;
import javafx.scene.control.Alert;
import javafx.scene.control.Alert.AlertType;
import javafx.scene.control.Button;
import javafx.scene.control.ComboBox;
import javafx.scene.control.Label;
import javafx.scene.control.TextField;
import javafx.scene.layout.GridPane;
import javafx.scene.layout.Priority;
import studyproject.API.Errors.ErrorFactory;
import studyproject.API.Lvl.Low.Broadcast;
import studyproject.API.Lvl.Mid.Core.UserInfo;
import studyproject.App;
import studyproject.logging.LogKey;

/**
 * Settings window. Load and edit properties
 * 
 * @author chris
 *
 */
public class SettingsWindowPresenter implements Initializable {

	@FXML
	Button applyButton;
	@FXML
	Button okButton;
	@FXML
	Button cancelButton;
	@FXML
	GridPane settingsGrid;

	private Logger logger;

	@Override
	public void initialize(URL location, ResourceBundle resources) {
		logger = Logger.getGlobal();
		okButton.setOnAction(ok -> okSettings());
		applyButton.setOnAction(apply -> applySettings());
		cancelButton.setOnAction(cancel -> cancelSettings());
		loadSettings();
	}

	/**
	 * Load Key-Value pairs from the properties file
	 */
	private void loadSettings() {
		for (Entry<Object, Object> entry : App.properties.entrySet()) {
			String key = (String) entry.getKey();
			String value = (String) entry.getValue();

			if (key == "pathToUserProperties") {
				continue;
			}

			Node node = settingsGrid.lookup("#" + key);
			if (node != null) {

				// defaultInterface ComboBox Interface
				if (key.equals("defaultInterface")) {
					ArrayList<String> na = new ArrayList<>();
					Broadcast.getNetworkAddresses(na);
					na.add("");
					@SuppressWarnings("unchecked")
					ComboBox<String> dd = (ComboBox<String>) node;
					dd.setItems(FXCollections.observableArrayList(na));
					dd.setValue(value);
				}
				// TextFields
				else {
					TextField txtNode = (TextField) node;
					txtNode.setText(value);

					if (key.equals("userName")) {
						// Live username validation
						txtNode.textProperty().addListener((observable, oldValue, newValue) -> {
							if (UserInfo.validateUserName(newValue)) {
								txtNode.setStyle("-fx-control-inner-background: #FFFFFF;");
							} else {
								txtNode.setStyle("-fx-control-inner-background: #FA9D9D;");
							}
						});
					}
				}

			}

		}

		for (Node node : settingsGrid.getChildren()) {
			GridPane.setVgrow(node, Priority.ALWAYS);
		}
	}

	/**
	 * Action that happens when pressing the 'OK' button. Executes functionality
	 * of the 'Apply' and 'Cancel' buttons
	 */
	private void okSettings() {
		if (applySettings())
			cancelSettings();
	}

	/**
	 * Action that happens when pressing the 'Apply' button. Saves the Key-Value
	 * pairs to the properties file Returns true if input is valid and data was
	 * saved successfully, otherwise false
	 */
	private Boolean applySettings() {
		ObservableList<Node> observList = settingsGrid.getChildren();
		Label label;
		TextField textField;

		for (Node l : observList) {
			if (l.getClass() != Label.class) {
				continue;
			}
			label = (Label) l;

			Node inputNode = label.getLabelFor();
						
			if (label.getStyleClass() != null && label.getStyleClass().contains("titleLabel")) {
				continue;
			}

			String propertyValue = "";

			if (inputNode instanceof TextField) {
				textField = (TextField) inputNode;
				propertyValue = textField.getText();

				// Show error message if username is invalid
				if (inputNode.getId().equals("userName") && UserInfo.validateUserName(textField.getText()) == false) {
					showInputError("Please make sure to choose a valid username. '" + textField.getText()
							+ "' is not a valid username.");
					return false;
				}

			} else if (inputNode instanceof ComboBox<?>) {
				@SuppressWarnings("unchecked")
				ComboBox<String> cBox = (ComboBox<String>) inputNode;
				propertyValue = cBox.getValue();
			}

			App.properties.setProperty(inputNode.getId(), propertyValue);

		}

		try {
			App.properties.store(new FileOutputStream(App.pathToProperties), null);
			logger.log(ErrorFactory.build(Level.INFO, LogKey.info, "Saved properties to " + App.pathToProperties));
			App.properties.load(new FileInputStream(new File(App.pathToProperties)));
			return true;
		} catch (FileNotFoundException e) {
			logger.log(ErrorFactory.build(Level.SEVERE, LogKey.error, "FileNotFoundException thrown: ", e));
		} catch (IOException e) {
			logger.log(ErrorFactory.build(Level.SEVERE, LogKey.error, "IOException thrown: ", e));
		}

		return false;
	}

	private void showInputError(String msg) {
		Alert alert = new Alert(AlertType.ERROR);
		alert.setTitle("Error");
		alert.setHeaderText("Invalid input");
		alert.setContentText(msg);
		alert.showAndWait();
	}

	/**
	 * Action that happens when pressing the 'Cancel' button. Close the
	 * 'Settings' window
	 */
	private void cancelSettings() {
		settingsGrid.getScene().getWindow().hide();
	}

}
