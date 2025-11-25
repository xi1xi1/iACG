// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:iacg/features/search/tabs/search_all_tab.dart';
// import 'package:iacg/features/search/tabs/search_cos_tab.dart';
// import 'package:iacg/features/search/tabs/search_island_tab.dart';
// import 'package:iacg/features/search/tabs/search_tags_tab.dart';
// import 'package:iacg/features/search/tabs/search_users_tab.dart';

// class SearchPage extends StatefulWidget {
//   const SearchPage({super.key});
//   @override
//   State<SearchPage> createState() => _SearchPageState();
// }

// class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
//   late final TabController _tab;
//   final _kw = ValueNotifier<String>('');
//   final _ctl = TextEditingController();
//   Timer? _debounce;

//   @override
//   void initState() {
//     super.initState();
//     _tab = TabController(length: 5, vsync: this); // 全部/COS/群岛/标签/用户
//   }

//   @override
//   void dispose() {
//     _debounce?.cancel();
//     _ctl.dispose();
//     _kw.dispose();
//     _tab.dispose();
//     super.dispose();
//   }

//   void _onChanged(String v) {
//     _debounce?.cancel();
//     _debounce = Timer(const Duration(milliseconds: 300), () {
//       _kw.value = v.trim();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         titleSpacing: 0,
//         title: Padding(
//           padding: const EdgeInsets.only(right: 8),
//           child: TextField(
//             controller: _ctl,
//             onChanged: _onChanged,
//             textInputAction: TextInputAction.search,
//             decoration: InputDecoration(
//               hintText: '搜索帖子、标签、用户',
//               filled: true,
//               fillColor: Theme.of(context).colorScheme.surfaceVariant,
//               border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
//               contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//               suffixIcon: _ctl.text.isEmpty
//                   ? const Icon(Icons.search)
//                   : IconButton(
//                       icon: const Icon(Icons.clear),
//                       onPressed: () {
//                         _ctl.clear();
//                         _kw.value = '';
//                       },
//                     ),
//             ),
//           ),
//         ),
//         bottom: TabBar(
//           controller: _tab,
//           isScrollable: true,
//           tabs: const [
//             Tab(text: '全部'),
//             Tab(text: 'COS'),
//             Tab(text: '群岛'),
//             Tab(text: '标签'),
//             Tab(text: '用户'),
//           ],
//         ),
//       ),
//       body: TabBarView(
//         controller: _tab,
//         children: [
//           SearchAllTab(keywordListenable: _kw),
//           SearchCosTab(keywordListenable: _kw),
//           SearchIslandTab(keywordListenable: _kw),
//           SearchTagsTab(keywordListenable: _kw), // ✅ 只有这里的卡片跳 TagPostsPage
//           SearchUsersTab(keywordListenable: _kw),
//         ],
//       ),
//     );
//   }
// }
// lib/pages/search/search_page.dart
import 'package:flutter/material.dart';
import 'package:iacg/features/search/tabs/search_all_tab.dart';
import 'package:iacg/features/search/tabs/search_cos_tab.dart';
import 'package:iacg/features/search/tabs/search_events_tab.dart';
import 'package:iacg/features/search/tabs/search_island_tab.dart';
import 'package:iacg/features/search/tabs/search_tags_tab.dart';
import 'package:iacg/features/search/tabs/search_users_tab.dart';
import 'package:iacg/services/search_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<String> _searchHistory = [];
  bool _showSearchResults = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  // 加载搜索历史
  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('search_history') ?? [];
    setState(() {
      _searchHistory = history;
    });
  }

  // 保存搜索历史
  Future<void> _saveSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 去重并限制数量
    if (_currentQuery.isNotEmpty) {
      _searchHistory.remove(_currentQuery);
      _searchHistory.insert(0, _currentQuery);
      
      if (_searchHistory.length > 10) {
        _searchHistory = _searchHistory.sublist(0, 10);
      }
      
      await prefs.setStringList('search_history', _searchHistory);
    }
  }

  // 执行搜索
  void _performSearch([String? query]) {
    final searchQuery = query ?? _searchController.text.trim();
    if (searchQuery.isEmpty) return;

    setState(() {
      _currentQuery = searchQuery;
      _showSearchResults = true;
    });

    // 保存到历史记录
    _saveSearchHistory();
    
    // 隐藏键盘
    _searchFocusNode.unfocus();
  }

  // 清空搜索历史
  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    setState(() {
      _searchHistory = [];
    });
  }

  // 删除单条历史记录
  Future<void> _deleteHistoryItem(int index) async {
    setState(() {
      _searchHistory.removeAt(index);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', _searchHistory);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildSearchField(),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _showSearchResults ? _buildSearchResults() : _buildSearchHistory(),
    );
  }

  // 构建搜索输入框
  Widget _buildSearchField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: '搜索内容、用户、标签...',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _showSearchResults = false;
                    });
                  },
                )
              : null,
          prefixIcon: IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () {
              if (_showSearchResults) {
                setState(() {
                  _showSearchResults = false;
                });
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        onSubmitted: (_) => _performSearch(),
        onChanged: (value) {
          setState(() {}); // 重新构建以更新清除按钮
        },
      ),
    );
  }

  // 构建搜索历史界面
  Widget _buildSearchHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 搜索历史标题
        if (_searchHistory.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '搜索历史',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: _clearSearchHistory,
                  child: Text(
                    '清空',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // 历史记录列表
        if (_searchHistory.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _searchHistory.length,
              itemBuilder: (context, index) {
                final historyItem = _searchHistory[index];
                return ListTile(
                  leading: const Icon(Icons.history, color: Colors.grey),
                  title: Text(historyItem),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => _deleteHistoryItem(index),
                  ),
                  onTap: () {
                    _searchController.text = historyItem;
                    _performSearch(historyItem);
                  },
                );
              },
            ),
          ),
        
        // 空状态
        if (_searchHistory.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无搜索历史',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // 构建搜索结果界面
  Widget _buildSearchResults() {
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          // Tab栏
          Container(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: const [
                Tab(text: '全部'),
                Tab(text: 'COS'),
                Tab(text: '群岛'),
                Tab(text: '活动'), 
                Tab(text: '标签'),
                Tab(text: '用户'),
              ],
            ),
          ),
          
          // Tab内容
          Expanded(
            child: TabBarView(
              children: [
                // 全部搜索
                SearchAllTab(
                  searchService: _searchService,
                  keyword: _currentQuery,
                ),
                // COS搜索
                SearchCosTab(
                  searchService: _searchService,
                  keyword: _currentQuery,
                ),
                // 群岛搜索
                SearchIslandTab(
                  searchService: _searchService,
                  keyword: _currentQuery,
                ),
                // ✅ 新增：活动搜索
                SearchEventsTab(
                  searchService: _searchService,
                  keyword: _currentQuery,
                ),
                // 标签搜索
                SearchTagsTab(
                  searchService: _searchService,
                  keyword: _currentQuery,
                ),
                // 用户搜索
                SearchUsersTab(
                  searchService: _searchService,
                  keyword: _currentQuery,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}