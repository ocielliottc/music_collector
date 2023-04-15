import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:elite_orm/elite_orm.dart';

import '../model/album.dart';
import '../database/database.dart';
import '../utility/musicbrainz.dart';
import '../utility/error_dialog.dart';
import '../style/style.dart';

// There is only one Bloc object that we will use on both this screen and the
// home screen.
final bloc = Bloc(Album(), DatabaseProvider.database);

class EditAlbum extends StatefulWidget {
  final Album? album;
  const EditAlbum({super.key, this.album});

  @override
  State<EditAlbum> createState() => EditAlbumState();
}

class EditAlbumState extends State<EditAlbum> {
  // Content editing
  bool _modified = false;
  int _minutes = 0;
  int _seconds = 0;
  final _artistController = TextEditingController();
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();

  // Keep track of searching and results.
  bool _searching = false;
  final List<Widget> _possible = [];

  // These are static so that we can cache the previous search automatically.
  static final List<Album> _albums = [];
  static final _searchController = TextEditingController();

  void _searchArtist() async {
    // The user may have just tapped the search icon.  If the keyboard is still
    // present, take away the focus so that it disappears.
    final FocusScopeNode currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }

    if (_searchController.text.isNotEmpty) {
      // Set the searching flag inside of a setState call so that the UI updates
      // with the progress indicator.
      setState(() => _searching = true);
      try {
        // Clear the list of possible album titles and the cache of Album
        // objects.
        _possible.clear();
        _albums.clear();

        // Get the matching albums and sort them on the release date
        _albums.addAll(await MusicBrainz().getAlbums(_searchController.text));
        _albums.sort((a, b) => a.release.compareTo(b.release));

        // Fill the search list with the albums
        _fillSearchList();

        // Clear the searching flag, now that the work is done.
        setState(() => _searching = false);
      } catch (err) {
        // Clear the searching flag before displaying the error dialog.
        setState(() => _searching = false);
        ErrorDialog.show(context, err.toString());
      }
    }
  }

  void _fillSearchList() {
    for (var album in _albums) {
      _possible.add(GestureDetector(
          child: Text(album.name), onTap: () => _fromAlbum(album)));
    }
  }

  Album _toAlbum() {
    final DateTime releaseDate = DateTime.parse(_dateController.text);
    final Duration duration = Duration(minutes: _minutes, seconds: _seconds);

    return Album(
        _artistController.text, _titleController.text, releaseDate, duration);
  }

  void _fromAlbum(Album album) {
    _artistController.text = album.artist;
    _titleController.text = album.name;
    _dateController.text = album.release.toIso8601String().substring(0, 10);
    _minutes = album.length.inSeconds ~/ 60;
    _seconds = album.length.inSeconds - (_minutes * 60);
  }

  void _saveAlbum() async {
    try {
      final Album album = _toAlbum();
      String message;
      if (album.artist.isNotEmpty && album.name.isNotEmpty) {
        if (widget.album == null) {
          await bloc.create(album);
          message = "Album Saved";
        } else {
          if (widget.album!.artist != album.artist ||
              widget.album!.name != album.name) {
            // Changing the name of the artist or album is the same as creating
            // a new album.  Because the artist and album make up the primary
            // key, we have to create the new album and delete the old one.
            // There's no way to just "rename" an entry in the database.
            await bloc.create(album);
            bloc.delete(widget.album!);
          } else {
            // If the artist and name has not changed, then we can update.
            await bloc.update(album);
          }
          message = "Album Updated";
        }
        _modified = false;

        // Because we're using the build context after an await, we need to
        // ensure that this widget is still mounted before using it.
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        message = "Invalid Album";
      }

      // Same here.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (err) {
      ErrorDialog.show(context, err.toString());
    }
  }

  void _deleteAlbum() async {
    if (widget.album != null) {
      try {
        await bloc.delete(widget.album);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (err) {
        ErrorDialog.show(context, err.toString());
      }
    }
  }

  void _pickDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      _dateController.text = date.toIso8601String().substring(0, 10);
    }
  }

  List<Widget> _bottomIcons() {
    List<Widget> children = [
      IconButton(
        icon: Icon(
          Icons.save,
          color: Theme.of(context).colorScheme.primary,
        ),
        iconSize: Style.iconSize,
        onPressed: _saveAlbum,
      ),
    ];
    if (widget.album != null) {
      children.add(
        IconButton(
          icon: Icon(
            Icons.delete_forever,
            color: Theme.of(context).colorScheme.primary,
          ),
          iconSize: Style.iconSize,
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Are you sure?"),
                content:
                    const Text("Are you sure you want to delete this album?"),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("No"),
                  ),
                  TextButton(
                    onPressed: () {
                      _deleteAlbum();
                      Navigator.of(context).pop(true);
                    },
                    child: const Text("Yes"),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
    return children;
  }

  Future<bool> _onWillPop() async {
    if (_modified) {
      return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Are you sure?"),
              content: const Text(
                  "You have changes that have not been saved.  Do you want to discard them?"),
              actions: <Widget>[
                TextButton(
                  // If the user presses no, we pop false so that the navigation
                  // does not proceed back to the previous screen.
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("No"),
                ),
                TextButton(
                  // If the user presses yes, we pop true so that after this
                  // dialog is destroyed, we navigate back to the previous
                  // screen.
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("Yes"),
                ),
              ],
            ),
          ) ??
          // Down here, the dialog was dismissed by touching outside of it,
          // which we will consider as the user telling us that they want to
          // stay on the current screen.
          false;
    }

    // True indicates that the screen can proceed to the previous navigation
    // point.  Since nothing was modified, the user wasn't even questioned.
    return true;
  }

  @override
  void initState() {
    super.initState();

    // Fill in the widgets with data.
    _fillSearchList();
    if (widget.album != null) {
      _fromAlbum(widget.album!);
    }

    // Set up listeners so that we can notify the user if there is unsaved data
    // when they leave this screen.
    _artistController.addListener(() => _modified = true);
    _titleController.addListener(() => _modified = true);
    _dateController.addListener(() => _modified = true);
  }

  Widget _renderContent() {
    List<Widget> content = [];
    if (widget.album == null) {
      content.addAll([
        const Padding(
          padding: Style.columnPadding,
          child: Text("Search by Artist", style: Style.titleText),
        ),
        Padding(
          padding: Style.columnPadding,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: Style.inputDecoration,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (s) => _searchArtist(),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: _searchArtist,
              ),
            ],
          ),
        ),
        Container(
          height: 100,
          margin: Style.columnPadding,
          padding: Style.columnPadding,
          decoration: Style.containerOutline(context),
          child: _searching
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const <Widget>[
                    CircularProgressIndicator(),
                    Text("Searching...", style: Style.titleText)
                  ],
                )
              : ListView(children: _possible),
        ),
      ]);
    }
    content.addAll([
      const Padding(
        padding: Style.columnPadding,
        child: Text("Artist", style: Style.titleText),
      ),
      Padding(
        padding: Style.textPadding,
        child: TextField(
          controller: _artistController,
          textCapitalization: TextCapitalization.words,
          decoration: Style.inputDecoration,
        ),
      ),
      const Padding(
        padding: Style.columnPadding,
        child: Text("Title", style: Style.titleText),
      ),
      Padding(
        padding: Style.textPadding,
        child: TextField(
          controller: _titleController,
          textCapitalization: TextCapitalization.words,
          decoration: Style.inputDecoration,
        ),
      ),
      const Padding(
        padding: Style.columnPadding,
        child: Text("Release Date", style: Style.titleText),
      ),
      Padding(
        padding: Style.columnPadding,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                readOnly: true,
                controller: _dateController,
                decoration: Style.inputDecoration,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.calendar_month,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: _pickDate,
            ),
          ],
        ),
      ),
      const Padding(
        padding: Style.columnPadding,
        child: Text("Duration", style: Style.titleText),
      ),
      Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(3),
        decoration: Style.containerOutline(context),
        child: Column(
          children: [
            Padding(
              padding: Style.columnPadding,
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        const Text("Minutes"),
                        NumberPicker(
                          value: _minutes,
                          axis: Axis.horizontal,
                          minValue: 0,
                          maxValue: 999,
                          itemWidth: 50,
                          onChanged: (value) => setState(() {
                            _minutes = value;
                            _modified = true;
                          }),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        const Text("Seconds"),
                        NumberPicker(
                          value: _seconds,
                          axis: Axis.horizontal,
                          minValue: 0,
                          maxValue: 59,
                          itemWidth: 50,
                          onChanged: (value) => setState(() {
                            _seconds = value;
                            _modified = true;
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ]);

    return ListView(children: content);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
            title: Text(widget.album == null ? "Add Album" : "Edit Album")),
        body: SafeArea(child: _renderContent()),
        bottomNavigationBar: BottomAppBar(
          child: Container(
            padding: Style.bottomBarPadding,
            decoration: Style.bottomBarDecoration(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _bottomIcons(),
            ),
          ),
        ),
      ),
    );
  }
}
