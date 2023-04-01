import 'package:flutter/material.dart';

import '../model/album.dart';
import '../screens/edit_album.dart';
import '../style/style.dart';

class ListAlbums extends StatefulWidget {
  const ListAlbums({super.key});

  @override
  State<ListAlbums> createState() => _ListAlbumsState();
}

class _ListAlbumsState extends State<ListAlbums> {
  Widget _renderAlbum(Album album) {
    return GestureDetector(
      child: Card(
        shape: Style.cardShape(context),
        child: ListTile(
          subtitle: Text(album.artist),
          title: Text(album.name, style: Style.cardTitleText),
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EditAlbum(album: album)),
        );
      },
    );
  }

  Widget _renderAlbums(AsyncSnapshot<List<Album>> snapshot) {
    if (snapshot.hasData) {
      // Sort the list by artist first and then the release date.
      snapshot.data!.sort((a, b) {
        final int cmp = a.artist.compareTo(b.artist);
        return cmp == 0 ? a.release.compareTo(b.release) : cmp;
      });
      return ListView.builder(
        itemCount: snapshot.data!.length,
        itemBuilder: (context, index) {
          return _renderAlbum(snapshot.data![index]);
        },
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const <Widget>[
            CircularProgressIndicator(),
            Text("Loading...", style: Style.titleText)
          ],
        ),
      );
    }
  }

  Widget _renderAlbumsWidget() {
    return StreamBuilder(
      stream: bloc.all,
      builder: (context, snapshot) => _renderAlbums(snapshot),
    );
  }

  List<Widget> _bottomIcons() {
    return [
      IconButton(
        icon: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
        iconSize: Style.iconSize,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EditAlbum()),
          );
        },
      ),
    ];
  }

  @override
  void initState() {
    super.initState();

    // Ensure that the bloc stream is filled.
    bloc.get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Music Collector")),
      body: SafeArea(child: _renderAlbumsWidget()),
      bottomNavigationBar: BottomAppBar(
        child: Container(
          padding: Style.bottomBarPadding,
          decoration: Style.bottomBarDecoration(context),
          child: Row(children: _bottomIcons()),
        ),
      ),
    );
  }
}
