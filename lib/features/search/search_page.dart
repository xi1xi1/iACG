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

  // 二次元风格颜色
  static const Color primaryPink = Color(0xFFED7099);
  static const Color secondaryPurple = Color(0xFF8B5CF6);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textLight = Color(0xFF6B7280);
  static const Color cardWhite = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    // 自动聚焦搜索框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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

    print('🔍 搜索页执行搜索: "$searchQuery"');
    print('📊 当前搜索状态: _showSearchResults=$_showSearchResults, _currentQuery="$_currentQuery"');

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
    print('🏗️ 搜索页构建: _showSearchResults=$_showSearchResults, _currentQuery="$_currentQuery"');
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: _buildSearchField(),
        backgroundColor: cardWhite,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: _showSearchResults ? _buildSearchResults() : _buildSearchHistory(),
    );
  }

  // 构建搜索输入框 - 二次元风格优化
  Widget _buildSearchField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: textLight,
              size: 20,
            ),
            onPressed: () {
              if (_showSearchResults) {
                setState(() {
                  _showSearchResults = false;
                  _searchController.clear();
                });
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          // 搜索输入框
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: '搜索内容、用户、标签...',
                hintStyle: TextStyle(color: textLight),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onSubmitted: (_) => _performSearch(),
              onChanged: (value) {
                setState(() {}); // 重新构建以更新清除按钮
              },
            ),
          ),
          // 清除/搜索按钮
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.clear,
                color: textLight,
                size: 20,
              ),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _showSearchResults = false;
                });
              },
            )
          else
            IconButton(
              icon: Icon(
                Icons.search,
                color: primaryPink,
                size: 20,
              ),
              onPressed: () => _performSearch(),
            ),
        ],
      ),
    );
  }

  // 构建热门搜索推荐
  Widget _buildHotSearches() {
    final hotSearches = [
      '鬼灭之刃',
      '动漫展',
      'COSPLAY',
      '摄影',
      '二次元',
      '漫展',
      '同人',
      '游戏',
      '周边'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            '热门搜索',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hotSearches.map((keyword) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = keyword;
                  _performSearch(keyword);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    keyword,
                    style: TextStyle(
                      color: textDark,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // 构建搜索历史界面 - 二次元风格优化
  Widget _buildSearchHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 热门搜索推荐
        _buildHotSearches(),
        
        // 搜索历史标题
        if (_searchHistory.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '搜索历史',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                GestureDetector(
                  onTap: _clearSearchHistory,
                  child: Text(
                    '清空',
                    style: TextStyle(
                      color: primaryPink,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _searchHistory.length,
              itemBuilder: (context, index) {
                final historyItem = _searchHistory[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: primaryPink.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.history,
                        color: primaryPink,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      historyItem,
                      style: TextStyle(
                        color: textDark,
                        fontSize: 15,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: textLight,
                      ),
                      onPressed: () => _deleteHistoryItem(index),
                    ),
                    onTap: () {
                      _searchController.text = historyItem;
                      _performSearch(historyItem);
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
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
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: primaryPink.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.search,
                      size: 40,
                      color: primaryPink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无搜索历史',
                    style: TextStyle(
                      color: textLight,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '输入关键词开始搜索吧',
                    style: TextStyle(
                      color: textLight.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // 构建搜索结果界面 - 二次元风格优化
  Widget _buildSearchResults() {
    print('📱 构建搜索结果界面: currentQuery="$_currentQuery"');
    return _SearchResultsView(
      searchService: _searchService,
      currentQuery: _currentQuery,
      onBack: () {
        setState(() {
          _showSearchResults = false;
        });
      },
    );
  }
}

// 独立的搜索结果视图组件，用于管理Tab状态
class _SearchResultsView extends StatefulWidget {
  final SearchService searchService;
  final String currentQuery;
  final VoidCallback onBack;

  const _SearchResultsView({
    required this.searchService,
    required this.currentQuery,
    required this.onBack,
  });

  @override
  State<_SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends State<_SearchResultsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 二次元风格颜色
    const Color primaryPink = Color(0xFFED7099);
    const Color textLight = Color(0xFF6B7280);
    const Color textDark = Color(0xFF1F2937);
    const Color cardWhite = Color(0xFFFFFFFF);

    return Column(
      children: [
        // 搜索结果标题
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: cardWhite,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '搜索结果: "${widget.currentQuery}"',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textDark,
                ),
              ),
              GestureDetector(
                onTap: widget.onBack,
                child: Text(
                  '返回',
                  style: TextStyle(
                    color: primaryPink,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Tab栏和内容 - 使用Expanded确保有足够的高度
        Expanded(
          child: Column(
            children: [
              // Tab栏 - 二次元风格
              Container(
                color: cardWhite,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false, // 设置为false，让Tab平均分配宽度
                  labelColor: primaryPink,
                  unselectedLabelColor: textLight,
                  indicatorColor: primaryPink,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: '全部'),
                    Tab(text: 'COS'),
                    Tab(text: '群岛'),
                    Tab(text: '活动'), 
                    Tab(text: '标签'),
                    Tab(text: '用户'),
                  ],
                  padding: EdgeInsets.zero, // 移除TabBar的内边距
                  labelPadding: EdgeInsets.zero, // 移除标签内边距
                ),
              ),
              
              // Tab内容 - 使用Expanded确保填充剩余空间
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 全部搜索
                    SearchAllTab(
                      searchService: widget.searchService,
                      keyword: widget.currentQuery,
                    ),
                    // COS搜索
                    SearchCosTab(
                      searchService: widget.searchService,
                      keyword: widget.currentQuery,
                    ),
                    // 群岛搜索
                    SearchIslandTab(
                      searchService: widget.searchService,
                      keyword: widget.currentQuery,
                    ),
                    // 活动搜索
                    SearchEventsTab(
                      searchService: widget.searchService,
                      keyword: widget.currentQuery,
                    ),
                    // 标签搜索
                    SearchTagsTab(
                      searchService: widget.searchService,
                      keyword: widget.currentQuery,
                    ),
                    // 用户搜索
                    SearchUsersTab(
                      searchService: widget.searchService,
                      keyword: widget.currentQuery,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
