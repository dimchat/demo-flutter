import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'styles.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  static Widget searchButton(BuildContext context) {
    return IconButton(
      iconSize: Styles.navigationBarIconSize,
      color: Styles.navigationBarIconColor,
      icon: const Icon(CupertinoIcons.search),
      onPressed: () => open(context),
    );
  }

  static void open(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => const SearchPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(
        border: null,
        automaticallyImplyLeading: false,
        middle: CupertinoSearchTextField(
          onSubmitted: _search,
        ),
        trailing: IconButton(
          iconSize: Styles.navigationBarIconSize,
          color: Styles.navigationBarIconColor,
          icon: const Icon(CupertinoIcons.clear),
          onPressed: () => {
            Navigator.pop(context)
          },
        ),
      ),
      body: const Center(
        child: Text('Search results'),
      ),
    );
  }

  void _search(value) {
    debugPrint('search $value');
  }
}
