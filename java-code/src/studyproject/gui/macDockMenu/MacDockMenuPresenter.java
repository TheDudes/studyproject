package studyproject.gui.macDockMenu;

import java.awt.MenuItem;
import java.awt.PopupMenu;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;

import javafx.application.Platform;
import studyproject.gui.mainWindow.topMenu.TopMenuPresenter;
import studyproject.gui.mainWindow.topMenu.TopMenuView;

/**
 * GUI for Mac OS specific dock menu
 * 
 * @author gitmalong
 *
 */
public class MacDockMenuPresenter {

	private TopMenuPresenter topMenuPresenter;

	/**
	 * Creates dock menu entries
	 */
	public void createMenus() {
		topMenuPresenter = (TopMenuPresenter) (new TopMenuView()).getPresenter();
		MenuItem shareFolder = new MenuItem("Share folder");
		// TODO gitmalong, this should work out fine without wrapping it in the
		// fx application thread
		// if not just revert this change
		shareFolder.addActionListener(e -> topMenuPresenter.shareFolderPressed());

		PopupMenu menu = new PopupMenu();
		menu.add(shareFolder);

		// set the dock menu
		com.apple.eawt.Application app = com.apple.eawt.Application.getApplication();
		app.setDockMenu(menu);
	}

}
