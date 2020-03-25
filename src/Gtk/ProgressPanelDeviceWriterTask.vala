/*
 * ProgressPanelDeviceWriterTask.vala
 *
 * Copyright 2012-18 Tony George <teejeetech@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */


using Gtk;
using Gee;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class ProgressPanelDeviceWriterTask : ProgressPanel {

	public DeviceWriterTask task;

	private DiskAction action;
	private Device device;
	private string iso_file = "";
	private string format = "";

	// ui
	public Gtk.Label lbl_header;
	public Gtk.Label lbl_status;
	public Gtk.Label lbl_stats;
	public Gtk.ProgressBar progressbar;

	public ProgressPanelDeviceWriterTask(FileViewPane _pane){
		init(_pane, null, FileActionType.ISO_WRITE);
	}

	public void set_parameters(DiskAction _action, string _iso_file, Device _device, string _format){
		action = _action;
		device = _device;
		iso_file = _iso_file;
		format = _format;
	}

	public override void init_ui(){ // TODO: make protected

		// heading ----------------

		var label = new Gtk.Label("");
		label.set_use_markup(true);
		label.xalign = 0.0f;
		label.margin_bottom = 12;
		contents.add(label);
		lbl_header = label;

		var hbox_outer = new Gtk.Box(Orientation.HORIZONTAL, 6);
		contents.add(hbox_outer);

		var vbox_outer = new Gtk.Box(Orientation.VERTICAL, 6);
		hbox_outer.add(vbox_outer);

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_outer.add(hbox);

		// spinner --------------------

		var spinner = new Gtk.Spinner();
		spinner.start();
		hbox.add(spinner);

		// status message ------------------

		label = new Gtk.Label(_("Preparing..."));
		label.xalign = 0.0f;
		label.ellipsize = Pango.EllipsizeMode.START;
		label.max_width_chars = 100;
		hbox.add(label);
		lbl_status = label;

		// progressbar ----------------------------

		progressbar = new Gtk.ProgressBar();
		progressbar.fraction = 0;
		progressbar.hexpand = true;
		vbox_outer.add(progressbar);

		// stats label ----------------

		label = new Gtk.Label("...");
		label.xalign = 0.0f;
		label.ellipsize = Pango.EllipsizeMode.END;
		label.max_width_chars = 100;
		vbox_outer.add(label);
		lbl_stats = label;

		// cancel button

		var button = new Gtk.Button.with_label("");
		button.label = "";
		button.image = IconManager.lookup_image("process-stop", 32);
		button.always_show_image = true;
		button.set_tooltip_text(_("Cancel"));
		hbox_outer.add(button);

		button.clicked.connect(()=>{
			cancel();
		});
	}

	public override void execute(){

		string txt = "";

		switch(action){
		case DiskAction.WRITE_ISO:
			txt = _("Flashing ISO to device...");
			break;
		case DiskAction.BACKUP:
			txt = _("Saving device to disk image...");
			break;
		case DiskAction.RESTORE:
			txt = _("Restoring device from disk image...");
			break;
		}

		txt = "<b>" + txt + "</b>";

		lbl_header.label = txt;

		task = new DeviceWriterTask();

		log_debug("ProgressPanelDeviceWriterTask: execute(%s)");

		pane.refresh_file_action_panel();
		pane.clear_messages();

		start_task();
	}

	public override void init_status(){

		log_debug("ProgressPanelDeviceWriterTask: init_status()");

		progressbar.fraction = 0.0;
		lbl_status.label = "Preparing...";
		lbl_stats.label = "";
	}

	public override void start_task(){

		log_debug("ProgressPanelDeviceWriterTask: start_task()");

		err_log_clear();

		switch(action){
		case DiskAction.WRITE_ISO:
			task.write_iso_to_device(iso_file, device);
			break;
		case DiskAction.BACKUP:
			task.backup_device(iso_file, device, format);
			break;
		case DiskAction.RESTORE:
			task.restore_device(iso_file, device, format);
			break;
		}

		gtk_do_events();

		tmr_status = Timeout.add (500, update_status);
	}

	public override bool update_status() {

		if (task.is_running){

			log_debug("ProgressPanelDeviceWriterTask: update_status()");

			lbl_status.label = "%s: %s".printf(_("File"), file_basename(iso_file));

			lbl_stats.label = task.stat_status_line;

			progressbar.fraction = task.progress;

			gtk_do_events();
		}
		else{
			finish();
			return false;
		}

		return true;
	}

	public override void cancel(){

		log_debug("ProgressPanelDeviceWriterTask: cancel()");

		aborted = true;

		stop_status_timer();

		if (task != null){
			task.stop();
		}

		finish();
	}

	public override void finish(){

		task_complete();

		stop_status_timer();

		log_debug("ProgressPanelDeviceWriterTask: finish()");

		pane.file_operations.remove(this);
		pane.refresh_file_action_panel();

		//log_debug("read_status(): %d".printf(task.read_status()));
		//log_debug("task.get_error_message()(): %s".printf(task.get_error_message()));

		if ((task.read_status() != 0) && (task.get_error_message().length > 0)){
			gtk_messagebox("Finished with errors", task.get_error_message(), window, true);
			//pane.add_message("%s: %s".printf(_("Error"), task.get_error_message()), Gtk.MessageType.ERROR);
		}
		else if (!aborted){

			switch(action){
			case DiskAction.WRITE_ISO:
				string txt = _("Flash Complete");
				string msg = _("Device safely ejected and ready for use");
				gtk_messagebox(txt, msg, window, false);
				break;

			case DiskAction.BACKUP:
				string txt = _("Backup Complete");
				string msg = _("Disk image was created successfully from device");
				gtk_messagebox(txt, msg, window, false);
				break;

			case DiskAction.RESTORE:
				string txt = _("Restore Complete");
				string msg = _("Device was restored successfully from disk image");
				gtk_messagebox(txt, msg, window, false);
				break;
			}

			//pane.add_message("%s - %s".printf(txt, msg), Gtk.MessageType.INFO);
		}
	}
}
