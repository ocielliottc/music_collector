import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../model/album.dart';

class MusicBrainz {
  static const String _apiURL = "https://musicbrainz.org/ws/2";

  String _getArtistURL(String artist) => "$_apiURL/artist?query=$artist";
  String _getReleasesURL(String artistId) =>
      "$_apiURL/artist/$artistId?inc=release-groups";

  dynamic _getNodeList(XmlDocument document, String elementName) {
    // We really want to return an XmlNodeList.  However, that class is
    // not exported.  So, we will use `dynamic` and build it out of the
    // element children.
    dynamic list;
    final elements = document.findAllElements(elementName);
    for (var element in elements) {
      // We can't construct an XmlNodeList.  So, if we don't have one yet
      // take the first element's XmlNodeList and add subsequent elements
      // children to it.
      if (list == null) {
        list = element.children;
      } else {
        list.addAll(element.children);
      }
    }
    return list;
  }

  String? _getElementText(XmlElement releaseGroup, String elementName) {
    XmlElement? element = releaseGroup.getElement(elementName);
    return element == null
        ? null
        : (element.children.isEmpty ? null : element.children.first.value);
  }

  List<String> _getArtistInfo(String groupName, String body) {
    // MusicBrainz returns a list of artists related to the string.
    // To simplify this example code, we're going to look for the exact match.
    // Barring that, we will just take the first in the list.
    String artistId = '';
    String artistName = '';
    XmlDocument document = XmlDocument.parse(body);
    final artists = _getNodeList(document, 'artist-list');
    if (artists != null) {
      String? firstId;
      String? firstName;
      for (var artist in artists) {
        final XmlElement? element = artist.getElement('name');
        final String? name = element?.children.first.value;
        if (name != null && name == groupName) {
          final String? id = artist.getAttribute('id');
          if (id != null) {
            artistId = id;
            artistName = name;
            break;
          }
        } else {
          // Take the id of the first artist (if first is null).
          firstId ??= artist.getAttribute('id');
          firstName ??= name;
        }
      }

      // If we didn't find an exact match, use the first artist
      // (if we found one).
      if (firstId != null && firstName != null) {
        artistId = firstId;
        artistName = firstName;
      }
    }
    return [artistId, artistName];
  }

  Album? _getAlbum(String artist, XmlElement releaseGroup) {
    // Get the title of the album
    final String? title = _getElementText(releaseGroup, 'title');
    if (title != null) {
      // See if this entry has a release date
      final String? release =
          _getElementText(releaseGroup, 'first-release-date');
      DateTime? releaseDate;
      if (release != null) {
        // The release date might not be parsable.  If it isn't, we may have to
        // punt.
        releaseDate = DateTime.tryParse(release);
        if (releaseDate == null) {
          // Sometimes, the entries only have a year...
          final int? year = int.tryParse(release);
          if (year != null) {
            releaseDate = DateTime(year);
          }
        }
      }
      return Album(artist, title, releaseDate);
    }
    return null;
  }

  List<Album> _getAlbums(String artist, String body) {
    List<Album> albums = [];
    final XmlDocument document = XmlDocument.parse(body);
    final releaseGroups = _getNodeList(document, 'release-group-list');
    if (releaseGroups != null) {
      for (var releaseGroup in releaseGroups) {
        final Album? album = _getAlbum(artist, releaseGroup);
        if (album != null) {
          albums.add(album);
        }
      }
    }
    return albums;
  }

  Future<List<Album>> getAlbums(String artist) async {
    // Request a list of artists that partially match "artist".
    http.Response response = await http.get(Uri.parse(_getArtistURL(artist)));
    if (response.statusCode == 200) {
      // Get the artist id from the response, if possible.
      final List<String> artistInfo = _getArtistInfo(artist, response.body);

      // Now request albums from the artist (if we found one).
      if (artistInfo.first.isNotEmpty) {
        final String artistId = artistInfo[0], artistName = artistInfo[1];
        response = await http.get(Uri.parse(_getReleasesURL(artistId)));
        if (response.statusCode == 200) {
          return _getAlbums(artistName, response.body);
        }
      }
    }
    return [];
  }
}
