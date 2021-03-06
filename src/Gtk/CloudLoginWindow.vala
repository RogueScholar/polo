/*
 * CloudLoginWindow.vala.vala
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

public class CloudLoginWindow : Gtk.Window, IPaneActive {

	private Gtk.Box vbox_main;
	private Gtk.SizeGroup size_label;
	private Gtk.SizeGroup size_combo;

	private MainWindow window;

	private Gtk.Entry txt_name;
	private Gtk.ComboBox cmb_type;
	private Gtk.Label lbl_message;
	private Gtk.Box box_name;
	private Gtk.Box box_type;

	private Gtk.Button btn_add;
	private Gtk.Button btn_cancel;
	private Gtk.Button btn_finish;

	public CloudLoginWindow(MainWindow _window) {

		set_transient_for(_window);
		window_position = WindowPosition.CENTER_ON_PARENT;

		window = _window;

		init_window();

		show_all();
	}

	private void init_window () {

		log_debug("CloudLoginWindow: init_window()");

		set_modal(true);
		set_skip_taskbar_hint(true);
		set_skip_pager_hint(true);
		icon = get_app_icon(16);
		deletable = true;
		resizable = false;

		set_title(_("Add Cloud Storage Account"));

		vbox_main = new Gtk.Box(Orientation.VERTICAL, 6);
		vbox_main.margin = 12;
		vbox_main.set_size_request(400,300);
		this.add(vbox_main);

		init_options();

		log_debug("CloudLoginWindow: init_window(): exit");
	}

	private void init_options() {

		log_debug("CloudLoginWindow: init_options()");

		size_label = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		size_combo = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);

		init_name();

		init_type();

		init_message();

		init_actions();
	}

	private void init_name() {

		log_debug("CloudLoginWindow: init_name()");

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		box_name = hbox;

		var label = new Gtk.Label (_("Account Name"));
		label.xalign = 1.0f;
		hbox.add(label);

		size_label.add_widget(label);

		var txt = new Gtk.Entry();
		txt.hexpand = true;
		txt.set_size_request(200,-1);
		hbox.add(txt);
		txt_name = txt;

		size_combo.add_widget(txt);

		txt.text = "Account 1";

		txt.changed.connect(() => {

			string text = txt.text;

			log_debug(text);

			for (int i = 0; i < text.length; i++){
				unichar c = text[i];
				if (!c.isalnum() && (c != ' ') && (c != '_') && (c != '-')){
					txt.text = text.replace(c.to_string(),"");
					return;
				}
			}
		});
	}

	private void init_type() {

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		box_type = hbox;

		var label = new Gtk.Label (_("Account Type"));
		label.xalign = 1.0f;
		hbox.add(label);

		size_label.add_widget(label);

		var combo = new Gtk.ComboBox();
		combo.hexpand = true;
		hbox.add(combo);
		cmb_type = combo;

		size_combo.add_widget(combo);

		var cell = new CellRendererText();
		combo.pack_start(cell, false);
		combo.set_attributes(cell, "text", 1);

		// add items ----------------

		var store = new Gtk.ListStore(2, typeof(string), typeof(string));
		combo.set_model(store);

		TreeIter iter;
		for(int i = 0; i < CloudAccount.account_type_names.length; i++){
			store.append(out iter);
			store.set (iter, 0, CloudAccount.account_types[i], 1, CloudAccount.account_type_names[i], -1);
			if (CloudAccount.account_types[i] == "drive"){
				combo.active = i;
			}
		}
	}

	private void init_message(){

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);

		string msg = "<span size=\"x-large\" weight=\"bold\">%s</span>\n\n%s\n\n%s".printf(
			_("Authorization was started"), _("Click 'Finish' to add the account"), _("Click 'Cancel' to close this window"));

		var label = new Gtk.Label(msg);
		label.set_use_markup(true);
		label.xalign = 0.0f;
		hbox.add(label);
		lbl_message = label;

		gtk_hide(lbl_message);
	}

	private void init_actions() {

		var label = new Gtk.Label("");
		label.vexpand = true;
		vbox_main.add(label);

		var box = new Gtk.ButtonBox(Orientation.HORIZONTAL);
		box.set_layout(Gtk.ButtonBoxStyle.CENTER);
		box.set_spacing(6);
		vbox_main.add(box);

		var button = new Gtk.Button.with_label(_("Cancel"));
		button.clicked.connect(btn_cancel_clicked);
		box.add(button);
		btn_cancel = button;

		button = new Gtk.Button.with_label(_("Next"));
		button.clicked.connect(btn_add_clicked);
		box.add(button);
		btn_add = button;

		button = new Gtk.Button.with_label(_("Finish"));
		//button.clicked.connect(btn_finish_clicked);
		box.add(button);
		btn_finish = button;

		gtk_show(btn_add);
		gtk_hide(btn_finish);

		btn_add.grab_focus();
	}

	// properties ------------------------------------------------------

	public string account_name {
		owned get {
			return txt_name.text;
		}
	}

	public string account_type {
		owned get {
			return gtk_combobox_get_value(cmb_type, 0, "drive");
		}
		set {
			gtk_combobox_set_value(cmb_type, 0, value);
		}
	}

	// selections ---------------------------------------------------

	private void btn_add_clicked(){

		log_debug("btn_add_clicked()");

		string txt = _("Account Configuration");
		string msg = _("Account setup will be started in a terminal window. Answer the prompts and finish setup to add account.");
		gtk_messagebox(txt, msg, this, false);

		string acc_name = account_name;
		string acc_type = account_type;

		Timeout.add(100, ()=>{
			window.run_rclone_config(acc_name, acc_type);
			return false;
		});

		this.destroy();
	}

	private void btn_cancel_clicked(){

		log_debug("btn_cancel_clicked()");

		this.destroy();
	}
}
