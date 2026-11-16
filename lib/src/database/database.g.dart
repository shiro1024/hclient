// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TagTable extends Tag with TableInfo<$TagTable, TagData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _namespaceMeta = const VerificationMeta(
    'namespace',
  );
  @override
  late final GeneratedColumn<String> namespace = GeneratedColumn<String>(
    'namespace',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    '_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _translatedNamespaceMeta =
      const VerificationMeta('translatedNamespace');
  @override
  late final GeneratedColumn<String> translatedNamespace =
      GeneratedColumn<String>(
        'translatedNamespace',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _tagNameMeta = const VerificationMeta(
    'tagName',
  );
  @override
  late final GeneratedColumn<String> tagName = GeneratedColumn<String>(
    'tagName',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fullTagNameMeta = const VerificationMeta(
    'fullTagName',
  );
  @override
  late final GeneratedColumn<String> fullTagName = GeneratedColumn<String>(
    'fullTagName',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _introMeta = const VerificationMeta('intro');
  @override
  late final GeneratedColumn<String> intro = GeneratedColumn<String>(
    'intro',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linksMeta = const VerificationMeta('links');
  @override
  late final GeneratedColumn<String> links = GeneratedColumn<String>(
    'links',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    namespace,
    key,
    translatedNamespace,
    tagName,
    fullTagName,
    intro,
    links,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('namespace')) {
      context.handle(
        _namespaceMeta,
        namespace.isAcceptableOrUnknown(data['namespace']!, _namespaceMeta),
      );
    } else if (isInserting) {
      context.missing(_namespaceMeta);
    }
    if (data.containsKey('_key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['_key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('translatedNamespace')) {
      context.handle(
        _translatedNamespaceMeta,
        translatedNamespace.isAcceptableOrUnknown(
          data['translatedNamespace']!,
          _translatedNamespaceMeta,
        ),
      );
    }
    if (data.containsKey('tagName')) {
      context.handle(
        _tagNameMeta,
        tagName.isAcceptableOrUnknown(data['tagName']!, _tagNameMeta),
      );
    }
    if (data.containsKey('fullTagName')) {
      context.handle(
        _fullTagNameMeta,
        fullTagName.isAcceptableOrUnknown(
          data['fullTagName']!,
          _fullTagNameMeta,
        ),
      );
    }
    if (data.containsKey('intro')) {
      context.handle(
        _introMeta,
        intro.isAcceptableOrUnknown(data['intro']!, _introMeta),
      );
    }
    if (data.containsKey('links')) {
      context.handle(
        _linksMeta,
        links.isAcceptableOrUnknown(data['links']!, _linksMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {namespace, key};
  @override
  TagData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagData(
      namespace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}namespace'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}_key'],
      )!,
      translatedNamespace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translatedNamespace'],
      ),
      tagName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tagName'],
      ),
      fullTagName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fullTagName'],
      ),
      intro: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intro'],
      ),
      links: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}links'],
      ),
    );
  }

  @override
  $TagTable createAlias(String alias) {
    return $TagTable(attachedDatabase, alias);
  }
}

class TagData extends DataClass implements Insertable<TagData> {
  final String namespace;
  final String key;
  final String? translatedNamespace;
  final String? tagName;
  final String? fullTagName;
  final String? intro;
  final String? links;
  const TagData({
    required this.namespace,
    required this.key,
    this.translatedNamespace,
    this.tagName,
    this.fullTagName,
    this.intro,
    this.links,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['namespace'] = Variable<String>(namespace);
    map['_key'] = Variable<String>(key);
    if (!nullToAbsent || translatedNamespace != null) {
      map['translatedNamespace'] = Variable<String>(translatedNamespace);
    }
    if (!nullToAbsent || tagName != null) {
      map['tagName'] = Variable<String>(tagName);
    }
    if (!nullToAbsent || fullTagName != null) {
      map['fullTagName'] = Variable<String>(fullTagName);
    }
    if (!nullToAbsent || intro != null) {
      map['intro'] = Variable<String>(intro);
    }
    if (!nullToAbsent || links != null) {
      map['links'] = Variable<String>(links);
    }
    return map;
  }

  TagCompanion toCompanion(bool nullToAbsent) {
    return TagCompanion(
      namespace: Value(namespace),
      key: Value(key),
      translatedNamespace: translatedNamespace == null && nullToAbsent
          ? const Value.absent()
          : Value(translatedNamespace),
      tagName: tagName == null && nullToAbsent
          ? const Value.absent()
          : Value(tagName),
      fullTagName: fullTagName == null && nullToAbsent
          ? const Value.absent()
          : Value(fullTagName),
      intro: intro == null && nullToAbsent
          ? const Value.absent()
          : Value(intro),
      links: links == null && nullToAbsent
          ? const Value.absent()
          : Value(links),
    );
  }

  factory TagData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagData(
      namespace: serializer.fromJson<String>(json['namespace']),
      key: serializer.fromJson<String>(json['_key']),
      translatedNamespace: serializer.fromJson<String?>(
        json['translatedNamespace'],
      ),
      tagName: serializer.fromJson<String?>(json['tagName']),
      fullTagName: serializer.fromJson<String?>(json['fullTagName']),
      intro: serializer.fromJson<String?>(json['intro']),
      links: serializer.fromJson<String?>(json['links']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'namespace': serializer.toJson<String>(namespace),
      '_key': serializer.toJson<String>(key),
      'translatedNamespace': serializer.toJson<String?>(translatedNamespace),
      'tagName': serializer.toJson<String?>(tagName),
      'fullTagName': serializer.toJson<String?>(fullTagName),
      'intro': serializer.toJson<String?>(intro),
      'links': serializer.toJson<String?>(links),
    };
  }

  TagData copyWith({
    String? namespace,
    String? key,
    Value<String?> translatedNamespace = const Value.absent(),
    Value<String?> tagName = const Value.absent(),
    Value<String?> fullTagName = const Value.absent(),
    Value<String?> intro = const Value.absent(),
    Value<String?> links = const Value.absent(),
  }) => TagData(
    namespace: namespace ?? this.namespace,
    key: key ?? this.key,
    translatedNamespace: translatedNamespace.present
        ? translatedNamespace.value
        : this.translatedNamespace,
    tagName: tagName.present ? tagName.value : this.tagName,
    fullTagName: fullTagName.present ? fullTagName.value : this.fullTagName,
    intro: intro.present ? intro.value : this.intro,
    links: links.present ? links.value : this.links,
  );
  TagData copyWithCompanion(TagCompanion data) {
    return TagData(
      namespace: data.namespace.present ? data.namespace.value : this.namespace,
      key: data.key.present ? data.key.value : this.key,
      translatedNamespace: data.translatedNamespace.present
          ? data.translatedNamespace.value
          : this.translatedNamespace,
      tagName: data.tagName.present ? data.tagName.value : this.tagName,
      fullTagName: data.fullTagName.present
          ? data.fullTagName.value
          : this.fullTagName,
      intro: data.intro.present ? data.intro.value : this.intro,
      links: data.links.present ? data.links.value : this.links,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagData(')
          ..write('namespace: $namespace, ')
          ..write('key: $key, ')
          ..write('translatedNamespace: $translatedNamespace, ')
          ..write('tagName: $tagName, ')
          ..write('fullTagName: $fullTagName, ')
          ..write('intro: $intro, ')
          ..write('links: $links')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    namespace,
    key,
    translatedNamespace,
    tagName,
    fullTagName,
    intro,
    links,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagData &&
          other.namespace == this.namespace &&
          other.key == this.key &&
          other.translatedNamespace == this.translatedNamespace &&
          other.tagName == this.tagName &&
          other.fullTagName == this.fullTagName &&
          other.intro == this.intro &&
          other.links == this.links);
}

class TagCompanion extends UpdateCompanion<TagData> {
  final Value<String> namespace;
  final Value<String> key;
  final Value<String?> translatedNamespace;
  final Value<String?> tagName;
  final Value<String?> fullTagName;
  final Value<String?> intro;
  final Value<String?> links;
  final Value<int> rowid;
  const TagCompanion({
    this.namespace = const Value.absent(),
    this.key = const Value.absent(),
    this.translatedNamespace = const Value.absent(),
    this.tagName = const Value.absent(),
    this.fullTagName = const Value.absent(),
    this.intro = const Value.absent(),
    this.links = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagCompanion.insert({
    required String namespace,
    required String key,
    this.translatedNamespace = const Value.absent(),
    this.tagName = const Value.absent(),
    this.fullTagName = const Value.absent(),
    this.intro = const Value.absent(),
    this.links = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : namespace = Value(namespace),
       key = Value(key);
  static Insertable<TagData> custom({
    Expression<String>? namespace,
    Expression<String>? key,
    Expression<String>? translatedNamespace,
    Expression<String>? tagName,
    Expression<String>? fullTagName,
    Expression<String>? intro,
    Expression<String>? links,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (namespace != null) 'namespace': namespace,
      if (key != null) '_key': key,
      if (translatedNamespace != null)
        'translatedNamespace': translatedNamespace,
      if (tagName != null) 'tagName': tagName,
      if (fullTagName != null) 'fullTagName': fullTagName,
      if (intro != null) 'intro': intro,
      if (links != null) 'links': links,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagCompanion copyWith({
    Value<String>? namespace,
    Value<String>? key,
    Value<String?>? translatedNamespace,
    Value<String?>? tagName,
    Value<String?>? fullTagName,
    Value<String?>? intro,
    Value<String?>? links,
    Value<int>? rowid,
  }) {
    return TagCompanion(
      namespace: namespace ?? this.namespace,
      key: key ?? this.key,
      translatedNamespace: translatedNamespace ?? this.translatedNamespace,
      tagName: tagName ?? this.tagName,
      fullTagName: fullTagName ?? this.fullTagName,
      intro: intro ?? this.intro,
      links: links ?? this.links,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (namespace.present) {
      map['namespace'] = Variable<String>(namespace.value);
    }
    if (key.present) {
      map['_key'] = Variable<String>(key.value);
    }
    if (translatedNamespace.present) {
      map['translatedNamespace'] = Variable<String>(translatedNamespace.value);
    }
    if (tagName.present) {
      map['tagName'] = Variable<String>(tagName.value);
    }
    if (fullTagName.present) {
      map['fullTagName'] = Variable<String>(fullTagName.value);
    }
    if (intro.present) {
      map['intro'] = Variable<String>(intro.value);
    }
    if (links.present) {
      map['links'] = Variable<String>(links.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagCompanion(')
          ..write('namespace: $namespace, ')
          ..write('key: $key, ')
          ..write('translatedNamespace: $translatedNamespace, ')
          ..write('tagName: $tagName, ')
          ..write('fullTagName: $fullTagName, ')
          ..write('intro: $intro, ')
          ..write('links: $links, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentCopyTable extends ContentCopy
    with TableInfo<$ContentCopyTable, ContentCopyData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentCopyTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _copyIdMeta = const VerificationMeta('copyId');
  @override
  late final GeneratedColumn<String> copyId = GeneratedColumn<String>(
    'copy_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
    'gid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _representationMeta = const VerificationMeta(
    'representation',
  );
  @override
  late final GeneratedColumn<String> representation = GeneratedColumn<String>(
    'representation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootPathMeta = const VerificationMeta(
    'rootPath',
  );
  @override
  late final GeneratedColumn<String> rootPath = GeneratedColumn<String>(
    'root_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _libraryNamespaceMeta = const VerificationMeta(
    'libraryNamespace',
  );
  @override
  late final GeneratedColumn<String> libraryNamespace = GeneratedColumn<String>(
    'library_namespace',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCurrentMeta = const VerificationMeta(
    'isCurrent',
  );
  @override
  late final GeneratedColumn<bool> isCurrent = GeneratedColumn<bool>(
    'is_current',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_current" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lifecycleMeta = const VerificationMeta(
    'lifecycle',
  );
  @override
  late final GeneratedColumn<String> lifecycle = GeneratedColumn<String>(
    'lifecycle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _trashPathMeta = const VerificationMeta(
    'trashPath',
  );
  @override
  late final GeneratedColumn<String> trashPath = GeneratedColumn<String>(
    'trash_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cleanupStateMeta = const VerificationMeta(
    'cleanupState',
  );
  @override
  late final GeneratedColumn<String> cleanupState = GeneratedColumn<String>(
    'cleanup_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    copyId,
    gid,
    representation,
    rootPath,
    metadataJson,
    libraryNamespace,
    isCurrent,
    lifecycle,
    trashPath,
    cleanupState,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_copy';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentCopyData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('copy_id')) {
      context.handle(
        _copyIdMeta,
        copyId.isAcceptableOrUnknown(data['copy_id']!, _copyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_copyIdMeta);
    }
    if (data.containsKey('gid')) {
      context.handle(
        _gidMeta,
        gid.isAcceptableOrUnknown(data['gid']!, _gidMeta),
      );
    } else if (isInserting) {
      context.missing(_gidMeta);
    }
    if (data.containsKey('representation')) {
      context.handle(
        _representationMeta,
        representation.isAcceptableOrUnknown(
          data['representation']!,
          _representationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_representationMeta);
    }
    if (data.containsKey('root_path')) {
      context.handle(
        _rootPathMeta,
        rootPath.isAcceptableOrUnknown(data['root_path']!, _rootPathMeta),
      );
    } else if (isInserting) {
      context.missing(_rootPathMeta);
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('library_namespace')) {
      context.handle(
        _libraryNamespaceMeta,
        libraryNamespace.isAcceptableOrUnknown(
          data['library_namespace']!,
          _libraryNamespaceMeta,
        ),
      );
    }
    if (data.containsKey('is_current')) {
      context.handle(
        _isCurrentMeta,
        isCurrent.isAcceptableOrUnknown(data['is_current']!, _isCurrentMeta),
      );
    }
    if (data.containsKey('lifecycle')) {
      context.handle(
        _lifecycleMeta,
        lifecycle.isAcceptableOrUnknown(data['lifecycle']!, _lifecycleMeta),
      );
    }
    if (data.containsKey('trash_path')) {
      context.handle(
        _trashPathMeta,
        trashPath.isAcceptableOrUnknown(data['trash_path']!, _trashPathMeta),
      );
    }
    if (data.containsKey('cleanup_state')) {
      context.handle(
        _cleanupStateMeta,
        cleanupState.isAcceptableOrUnknown(
          data['cleanup_state']!,
          _cleanupStateMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {copyId};
  @override
  ContentCopyData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentCopyData(
      copyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}copy_id'],
      )!,
      gid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gid'],
      )!,
      representation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}representation'],
      )!,
      rootPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_path'],
      )!,
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      ),
      libraryNamespace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_namespace'],
      ),
      isCurrent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_current'],
      )!,
      lifecycle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lifecycle'],
      )!,
      trashPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trash_path'],
      ),
      cleanupState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cleanup_state'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ContentCopyTable createAlias(String alias) {
    return $ContentCopyTable(attachedDatabase, alias);
  }
}

class ContentCopyData extends DataClass implements Insertable<ContentCopyData> {
  final String copyId;
  final int gid;
  final String representation;
  final String rootPath;
  final String? metadataJson;
  final String? libraryNamespace;
  final bool isCurrent;
  final String lifecycle;
  final String? trashPath;
  final String? cleanupState;
  final String createdAt;
  const ContentCopyData({
    required this.copyId,
    required this.gid,
    required this.representation,
    required this.rootPath,
    this.metadataJson,
    this.libraryNamespace,
    required this.isCurrent,
    required this.lifecycle,
    this.trashPath,
    this.cleanupState,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['copy_id'] = Variable<String>(copyId);
    map['gid'] = Variable<int>(gid);
    map['representation'] = Variable<String>(representation);
    map['root_path'] = Variable<String>(rootPath);
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    if (!nullToAbsent || libraryNamespace != null) {
      map['library_namespace'] = Variable<String>(libraryNamespace);
    }
    map['is_current'] = Variable<bool>(isCurrent);
    map['lifecycle'] = Variable<String>(lifecycle);
    if (!nullToAbsent || trashPath != null) {
      map['trash_path'] = Variable<String>(trashPath);
    }
    if (!nullToAbsent || cleanupState != null) {
      map['cleanup_state'] = Variable<String>(cleanupState);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  ContentCopyCompanion toCompanion(bool nullToAbsent) {
    return ContentCopyCompanion(
      copyId: Value(copyId),
      gid: Value(gid),
      representation: Value(representation),
      rootPath: Value(rootPath),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
      libraryNamespace: libraryNamespace == null && nullToAbsent
          ? const Value.absent()
          : Value(libraryNamespace),
      isCurrent: Value(isCurrent),
      lifecycle: Value(lifecycle),
      trashPath: trashPath == null && nullToAbsent
          ? const Value.absent()
          : Value(trashPath),
      cleanupState: cleanupState == null && nullToAbsent
          ? const Value.absent()
          : Value(cleanupState),
      createdAt: Value(createdAt),
    );
  }

  factory ContentCopyData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentCopyData(
      copyId: serializer.fromJson<String>(json['copyId']),
      gid: serializer.fromJson<int>(json['gid']),
      representation: serializer.fromJson<String>(json['representation']),
      rootPath: serializer.fromJson<String>(json['rootPath']),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
      libraryNamespace: serializer.fromJson<String?>(json['libraryNamespace']),
      isCurrent: serializer.fromJson<bool>(json['isCurrent']),
      lifecycle: serializer.fromJson<String>(json['lifecycle']),
      trashPath: serializer.fromJson<String?>(json['trashPath']),
      cleanupState: serializer.fromJson<String?>(json['cleanupState']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'copyId': serializer.toJson<String>(copyId),
      'gid': serializer.toJson<int>(gid),
      'representation': serializer.toJson<String>(representation),
      'rootPath': serializer.toJson<String>(rootPath),
      'metadataJson': serializer.toJson<String?>(metadataJson),
      'libraryNamespace': serializer.toJson<String?>(libraryNamespace),
      'isCurrent': serializer.toJson<bool>(isCurrent),
      'lifecycle': serializer.toJson<String>(lifecycle),
      'trashPath': serializer.toJson<String?>(trashPath),
      'cleanupState': serializer.toJson<String?>(cleanupState),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  ContentCopyData copyWith({
    String? copyId,
    int? gid,
    String? representation,
    String? rootPath,
    Value<String?> metadataJson = const Value.absent(),
    Value<String?> libraryNamespace = const Value.absent(),
    bool? isCurrent,
    String? lifecycle,
    Value<String?> trashPath = const Value.absent(),
    Value<String?> cleanupState = const Value.absent(),
    String? createdAt,
  }) => ContentCopyData(
    copyId: copyId ?? this.copyId,
    gid: gid ?? this.gid,
    representation: representation ?? this.representation,
    rootPath: rootPath ?? this.rootPath,
    metadataJson: metadataJson.present ? metadataJson.value : this.metadataJson,
    libraryNamespace: libraryNamespace.present
        ? libraryNamespace.value
        : this.libraryNamespace,
    isCurrent: isCurrent ?? this.isCurrent,
    lifecycle: lifecycle ?? this.lifecycle,
    trashPath: trashPath.present ? trashPath.value : this.trashPath,
    cleanupState: cleanupState.present ? cleanupState.value : this.cleanupState,
    createdAt: createdAt ?? this.createdAt,
  );
  ContentCopyData copyWithCompanion(ContentCopyCompanion data) {
    return ContentCopyData(
      copyId: data.copyId.present ? data.copyId.value : this.copyId,
      gid: data.gid.present ? data.gid.value : this.gid,
      representation: data.representation.present
          ? data.representation.value
          : this.representation,
      rootPath: data.rootPath.present ? data.rootPath.value : this.rootPath,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      libraryNamespace: data.libraryNamespace.present
          ? data.libraryNamespace.value
          : this.libraryNamespace,
      isCurrent: data.isCurrent.present ? data.isCurrent.value : this.isCurrent,
      lifecycle: data.lifecycle.present ? data.lifecycle.value : this.lifecycle,
      trashPath: data.trashPath.present ? data.trashPath.value : this.trashPath,
      cleanupState: data.cleanupState.present
          ? data.cleanupState.value
          : this.cleanupState,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentCopyData(')
          ..write('copyId: $copyId, ')
          ..write('gid: $gid, ')
          ..write('representation: $representation, ')
          ..write('rootPath: $rootPath, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('libraryNamespace: $libraryNamespace, ')
          ..write('isCurrent: $isCurrent, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('trashPath: $trashPath, ')
          ..write('cleanupState: $cleanupState, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    copyId,
    gid,
    representation,
    rootPath,
    metadataJson,
    libraryNamespace,
    isCurrent,
    lifecycle,
    trashPath,
    cleanupState,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentCopyData &&
          other.copyId == this.copyId &&
          other.gid == this.gid &&
          other.representation == this.representation &&
          other.rootPath == this.rootPath &&
          other.metadataJson == this.metadataJson &&
          other.libraryNamespace == this.libraryNamespace &&
          other.isCurrent == this.isCurrent &&
          other.lifecycle == this.lifecycle &&
          other.trashPath == this.trashPath &&
          other.cleanupState == this.cleanupState &&
          other.createdAt == this.createdAt);
}

class ContentCopyCompanion extends UpdateCompanion<ContentCopyData> {
  final Value<String> copyId;
  final Value<int> gid;
  final Value<String> representation;
  final Value<String> rootPath;
  final Value<String?> metadataJson;
  final Value<String?> libraryNamespace;
  final Value<bool> isCurrent;
  final Value<String> lifecycle;
  final Value<String?> trashPath;
  final Value<String?> cleanupState;
  final Value<String> createdAt;
  final Value<int> rowid;
  const ContentCopyCompanion({
    this.copyId = const Value.absent(),
    this.gid = const Value.absent(),
    this.representation = const Value.absent(),
    this.rootPath = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.libraryNamespace = const Value.absent(),
    this.isCurrent = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.trashPath = const Value.absent(),
    this.cleanupState = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentCopyCompanion.insert({
    required String copyId,
    required int gid,
    required String representation,
    required String rootPath,
    this.metadataJson = const Value.absent(),
    this.libraryNamespace = const Value.absent(),
    this.isCurrent = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.trashPath = const Value.absent(),
    this.cleanupState = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : copyId = Value(copyId),
       gid = Value(gid),
       representation = Value(representation),
       rootPath = Value(rootPath),
       createdAt = Value(createdAt);
  static Insertable<ContentCopyData> custom({
    Expression<String>? copyId,
    Expression<int>? gid,
    Expression<String>? representation,
    Expression<String>? rootPath,
    Expression<String>? metadataJson,
    Expression<String>? libraryNamespace,
    Expression<bool>? isCurrent,
    Expression<String>? lifecycle,
    Expression<String>? trashPath,
    Expression<String>? cleanupState,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (copyId != null) 'copy_id': copyId,
      if (gid != null) 'gid': gid,
      if (representation != null) 'representation': representation,
      if (rootPath != null) 'root_path': rootPath,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (libraryNamespace != null) 'library_namespace': libraryNamespace,
      if (isCurrent != null) 'is_current': isCurrent,
      if (lifecycle != null) 'lifecycle': lifecycle,
      if (trashPath != null) 'trash_path': trashPath,
      if (cleanupState != null) 'cleanup_state': cleanupState,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentCopyCompanion copyWith({
    Value<String>? copyId,
    Value<int>? gid,
    Value<String>? representation,
    Value<String>? rootPath,
    Value<String?>? metadataJson,
    Value<String?>? libraryNamespace,
    Value<bool>? isCurrent,
    Value<String>? lifecycle,
    Value<String?>? trashPath,
    Value<String?>? cleanupState,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return ContentCopyCompanion(
      copyId: copyId ?? this.copyId,
      gid: gid ?? this.gid,
      representation: representation ?? this.representation,
      rootPath: rootPath ?? this.rootPath,
      metadataJson: metadataJson ?? this.metadataJson,
      libraryNamespace: libraryNamespace ?? this.libraryNamespace,
      isCurrent: isCurrent ?? this.isCurrent,
      lifecycle: lifecycle ?? this.lifecycle,
      trashPath: trashPath ?? this.trashPath,
      cleanupState: cleanupState ?? this.cleanupState,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (copyId.present) {
      map['copy_id'] = Variable<String>(copyId.value);
    }
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (representation.present) {
      map['representation'] = Variable<String>(representation.value);
    }
    if (rootPath.present) {
      map['root_path'] = Variable<String>(rootPath.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (libraryNamespace.present) {
      map['library_namespace'] = Variable<String>(libraryNamespace.value);
    }
    if (isCurrent.present) {
      map['is_current'] = Variable<bool>(isCurrent.value);
    }
    if (lifecycle.present) {
      map['lifecycle'] = Variable<String>(lifecycle.value);
    }
    if (trashPath.present) {
      map['trash_path'] = Variable<String>(trashPath.value);
    }
    if (cleanupState.present) {
      map['cleanup_state'] = Variable<String>(cleanupState.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentCopyCompanion(')
          ..write('copyId: $copyId, ')
          ..write('gid: $gid, ')
          ..write('representation: $representation, ')
          ..write('rootPath: $rootPath, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('libraryNamespace: $libraryNamespace, ')
          ..write('isCurrent: $isCurrent, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('trashPath: $trashPath, ')
          ..write('cleanupState: $cleanupState, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArchiveDownloadedTable extends ArchiveDownloaded
    with TableInfo<$ArchiveDownloadedTable, ArchiveDownloadedData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArchiveDownloadedTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
    'gid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _copyIdMeta = const VerificationMeta('copyId');
  @override
  late final GeneratedColumn<String> copyId = GeneratedColumn<String>(
    'copy_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES content_copy (copy_id)',
    ),
  );
  static const VerificationMeta _tokenMeta = const VerificationMeta('token');
  @override
  late final GeneratedColumn<String> token = GeneratedColumn<String>(
    'token',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _galleryUrlMeta = const VerificationMeta(
    'galleryUrl',
  );
  @override
  late final GeneratedColumn<String> galleryUrl = GeneratedColumn<String>(
    'gallery_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uploaderMeta = const VerificationMeta(
    'uploader',
  );
  @override
  late final GeneratedColumn<String> uploader = GeneratedColumn<String>(
    'uploader',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publishTimeMeta = const VerificationMeta(
    'publishTime',
  );
  @override
  late final GeneratedColumn<String> publishTime = GeneratedColumn<String>(
    'publish_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archiveStatusCodeMeta = const VerificationMeta(
    'archiveStatusCode',
  );
  @override
  late final GeneratedColumn<int> archiveStatusCode = GeneratedColumn<int>(
    'archive_status_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivePageUrlMeta = const VerificationMeta(
    'archivePageUrl',
  );
  @override
  late final GeneratedColumn<String> archivePageUrl = GeneratedColumn<String>(
    'archive_page_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadPageUrlMeta = const VerificationMeta(
    'downloadPageUrl',
  );
  @override
  late final GeneratedColumn<String> downloadPageUrl = GeneratedColumn<String>(
    'download_page_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadUrlMeta = const VerificationMeta(
    'downloadUrl',
  );
  @override
  late final GeneratedColumn<String> downloadUrl = GeneratedColumn<String>(
    'download_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isOriginalMeta = const VerificationMeta(
    'isOriginal',
  );
  @override
  late final GeneratedColumn<bool> isOriginal = GeneratedColumn<bool>(
    'is_original',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_original" IN (0, 1))',
    ),
  );
  static const VerificationMeta _insertTimeMeta = const VerificationMeta(
    'insertTime',
  );
  @override
  late final GeneratedColumn<String> insertTime = GeneratedColumn<String>(
    'insert_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _tagRefreshTimeMeta = const VerificationMeta(
    'tagRefreshTime',
  );
  @override
  late final GeneratedColumn<String> tagRefreshTime = GeneratedColumn<String>(
    'tag_refresh_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parseSourceMeta = const VerificationMeta(
    'parseSource',
  );
  @override
  late final GeneratedColumn<int> parseSource = GeneratedColumn<int>(
    'parse_source',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sanitizedTitleMeta = const VerificationMeta(
    'sanitizedTitle',
  );
  @override
  late final GeneratedColumn<String> sanitizedTitle = GeneratedColumn<String>(
    'sanitized_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    gid,
    copyId,
    token,
    title,
    category,
    pageCount,
    galleryUrl,
    coverUrl,
    uploader,
    size,
    publishTime,
    archiveStatusCode,
    archivePageUrl,
    downloadPageUrl,
    downloadUrl,
    isOriginal,
    insertTime,
    sortOrder,
    groupName,
    tags,
    tagRefreshTime,
    parseSource,
    sanitizedTitle,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'archive_downloaded_v2';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArchiveDownloadedData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gid')) {
      context.handle(
        _gidMeta,
        gid.isAcceptableOrUnknown(data['gid']!, _gidMeta),
      );
    }
    if (data.containsKey('copy_id')) {
      context.handle(
        _copyIdMeta,
        copyId.isAcceptableOrUnknown(data['copy_id']!, _copyIdMeta),
      );
    }
    if (data.containsKey('token')) {
      context.handle(
        _tokenMeta,
        token.isAcceptableOrUnknown(data['token']!, _tokenMeta),
      );
    } else if (isInserting) {
      context.missing(_tokenMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    } else if (isInserting) {
      context.missing(_pageCountMeta);
    }
    if (data.containsKey('gallery_url')) {
      context.handle(
        _galleryUrlMeta,
        galleryUrl.isAcceptableOrUnknown(data['gallery_url']!, _galleryUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_galleryUrlMeta);
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_coverUrlMeta);
    }
    if (data.containsKey('uploader')) {
      context.handle(
        _uploaderMeta,
        uploader.isAcceptableOrUnknown(data['uploader']!, _uploaderMeta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('publish_time')) {
      context.handle(
        _publishTimeMeta,
        publishTime.isAcceptableOrUnknown(
          data['publish_time']!,
          _publishTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publishTimeMeta);
    }
    if (data.containsKey('archive_status_index')) {
      context.handle(
        _archiveStatusCodeMeta,
        archiveStatusCode.isAcceptableOrUnknown(
          data['archive_status_index']!,
          _archiveStatusCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_archiveStatusCodeMeta);
    }
    if (data.containsKey('archive_page_url')) {
      context.handle(
        _archivePageUrlMeta,
        archivePageUrl.isAcceptableOrUnknown(
          data['archive_page_url']!,
          _archivePageUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_archivePageUrlMeta);
    }
    if (data.containsKey('download_page_url')) {
      context.handle(
        _downloadPageUrlMeta,
        downloadPageUrl.isAcceptableOrUnknown(
          data['download_page_url']!,
          _downloadPageUrlMeta,
        ),
      );
    }
    if (data.containsKey('download_url')) {
      context.handle(
        _downloadUrlMeta,
        downloadUrl.isAcceptableOrUnknown(
          data['download_url']!,
          _downloadUrlMeta,
        ),
      );
    }
    if (data.containsKey('is_original')) {
      context.handle(
        _isOriginalMeta,
        isOriginal.isAcceptableOrUnknown(data['is_original']!, _isOriginalMeta),
      );
    } else if (isInserting) {
      context.missing(_isOriginalMeta);
    }
    if (data.containsKey('insert_time')) {
      context.handle(
        _insertTimeMeta,
        insertTime.isAcceptableOrUnknown(data['insert_time']!, _insertTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_insertTimeMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    } else if (isInserting) {
      context.missing(_groupNameMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('tag_refresh_time')) {
      context.handle(
        _tagRefreshTimeMeta,
        tagRefreshTime.isAcceptableOrUnknown(
          data['tag_refresh_time']!,
          _tagRefreshTimeMeta,
        ),
      );
    }
    if (data.containsKey('parse_source')) {
      context.handle(
        _parseSourceMeta,
        parseSource.isAcceptableOrUnknown(
          data['parse_source']!,
          _parseSourceMeta,
        ),
      );
    }
    if (data.containsKey('sanitized_title')) {
      context.handle(
        _sanitizedTitleMeta,
        sanitizedTitle.isAcceptableOrUnknown(
          data['sanitized_title']!,
          _sanitizedTitleMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid};
  @override
  ArchiveDownloadedData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArchiveDownloadedData(
      gid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gid'],
      )!,
      copyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}copy_id'],
      ),
      token: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      galleryUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gallery_url'],
      )!,
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      )!,
      uploader: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uploader'],
      ),
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      publishTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publish_time'],
      )!,
      archiveStatusCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archive_status_index'],
      )!,
      archivePageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archive_page_url'],
      )!,
      downloadPageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_page_url'],
      ),
      downloadUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_url'],
      ),
      isOriginal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_original'],
      )!,
      insertTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}insert_time'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      tagRefreshTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_refresh_time'],
      ),
      parseSource: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parse_source'],
      )!,
      sanitizedTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sanitized_title'],
      ),
    );
  }

  @override
  $ArchiveDownloadedTable createAlias(String alias) {
    return $ArchiveDownloadedTable(attachedDatabase, alias);
  }
}

class ArchiveDownloadedData extends DataClass
    implements Insertable<ArchiveDownloadedData> {
  final int gid;
  final String? copyId;
  final String token;
  final String title;
  final String category;
  final int pageCount;
  final String galleryUrl;
  final String coverUrl;
  final String? uploader;
  final int size;
  final String publishTime;
  final int archiveStatusCode;
  final String archivePageUrl;
  final String? downloadPageUrl;
  final String? downloadUrl;
  final bool isOriginal;
  final String insertTime;
  final int sortOrder;
  final String groupName;
  final String tags;
  final String? tagRefreshTime;
  final int parseSource;

  /// Sanitized and truncated title used as the directory/file name on disk.
  /// Computed once when the download task is first created and stored here to
  /// ensure the path never changes even if the truncation algorithm is updated.
  final String? sanitizedTitle;
  const ArchiveDownloadedData({
    required this.gid,
    this.copyId,
    required this.token,
    required this.title,
    required this.category,
    required this.pageCount,
    required this.galleryUrl,
    required this.coverUrl,
    this.uploader,
    required this.size,
    required this.publishTime,
    required this.archiveStatusCode,
    required this.archivePageUrl,
    this.downloadPageUrl,
    this.downloadUrl,
    required this.isOriginal,
    required this.insertTime,
    required this.sortOrder,
    required this.groupName,
    required this.tags,
    this.tagRefreshTime,
    required this.parseSource,
    this.sanitizedTitle,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gid'] = Variable<int>(gid);
    if (!nullToAbsent || copyId != null) {
      map['copy_id'] = Variable<String>(copyId);
    }
    map['token'] = Variable<String>(token);
    map['title'] = Variable<String>(title);
    map['category'] = Variable<String>(category);
    map['page_count'] = Variable<int>(pageCount);
    map['gallery_url'] = Variable<String>(galleryUrl);
    map['cover_url'] = Variable<String>(coverUrl);
    if (!nullToAbsent || uploader != null) {
      map['uploader'] = Variable<String>(uploader);
    }
    map['size'] = Variable<int>(size);
    map['publish_time'] = Variable<String>(publishTime);
    map['archive_status_index'] = Variable<int>(archiveStatusCode);
    map['archive_page_url'] = Variable<String>(archivePageUrl);
    if (!nullToAbsent || downloadPageUrl != null) {
      map['download_page_url'] = Variable<String>(downloadPageUrl);
    }
    if (!nullToAbsent || downloadUrl != null) {
      map['download_url'] = Variable<String>(downloadUrl);
    }
    map['is_original'] = Variable<bool>(isOriginal);
    map['insert_time'] = Variable<String>(insertTime);
    map['sort_order'] = Variable<int>(sortOrder);
    map['group_name'] = Variable<String>(groupName);
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || tagRefreshTime != null) {
      map['tag_refresh_time'] = Variable<String>(tagRefreshTime);
    }
    map['parse_source'] = Variable<int>(parseSource);
    if (!nullToAbsent || sanitizedTitle != null) {
      map['sanitized_title'] = Variable<String>(sanitizedTitle);
    }
    return map;
  }

  ArchiveDownloadedCompanion toCompanion(bool nullToAbsent) {
    return ArchiveDownloadedCompanion(
      gid: Value(gid),
      copyId: copyId == null && nullToAbsent
          ? const Value.absent()
          : Value(copyId),
      token: Value(token),
      title: Value(title),
      category: Value(category),
      pageCount: Value(pageCount),
      galleryUrl: Value(galleryUrl),
      coverUrl: Value(coverUrl),
      uploader: uploader == null && nullToAbsent
          ? const Value.absent()
          : Value(uploader),
      size: Value(size),
      publishTime: Value(publishTime),
      archiveStatusCode: Value(archiveStatusCode),
      archivePageUrl: Value(archivePageUrl),
      downloadPageUrl: downloadPageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadPageUrl),
      downloadUrl: downloadUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadUrl),
      isOriginal: Value(isOriginal),
      insertTime: Value(insertTime),
      sortOrder: Value(sortOrder),
      groupName: Value(groupName),
      tags: Value(tags),
      tagRefreshTime: tagRefreshTime == null && nullToAbsent
          ? const Value.absent()
          : Value(tagRefreshTime),
      parseSource: Value(parseSource),
      sanitizedTitle: sanitizedTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(sanitizedTitle),
    );
  }

  factory ArchiveDownloadedData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArchiveDownloadedData(
      gid: serializer.fromJson<int>(json['gid']),
      copyId: serializer.fromJson<String?>(json['copyId']),
      token: serializer.fromJson<String>(json['token']),
      title: serializer.fromJson<String>(json['title']),
      category: serializer.fromJson<String>(json['category']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      galleryUrl: serializer.fromJson<String>(json['galleryUrl']),
      coverUrl: serializer.fromJson<String>(json['coverUrl']),
      uploader: serializer.fromJson<String?>(json['uploader']),
      size: serializer.fromJson<int>(json['size']),
      publishTime: serializer.fromJson<String>(json['publishTime']),
      archiveStatusCode: serializer.fromJson<int>(json['archiveStatusCode']),
      archivePageUrl: serializer.fromJson<String>(json['archivePageUrl']),
      downloadPageUrl: serializer.fromJson<String?>(json['downloadPageUrl']),
      downloadUrl: serializer.fromJson<String?>(json['downloadUrl']),
      isOriginal: serializer.fromJson<bool>(json['isOriginal']),
      insertTime: serializer.fromJson<String>(json['insertTime']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      groupName: serializer.fromJson<String>(json['groupName']),
      tags: serializer.fromJson<String>(json['tags']),
      tagRefreshTime: serializer.fromJson<String?>(json['tagRefreshTime']),
      parseSource: serializer.fromJson<int>(json['parseSource']),
      sanitizedTitle: serializer.fromJson<String?>(json['sanitizedTitle']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gid': serializer.toJson<int>(gid),
      'copyId': serializer.toJson<String?>(copyId),
      'token': serializer.toJson<String>(token),
      'title': serializer.toJson<String>(title),
      'category': serializer.toJson<String>(category),
      'pageCount': serializer.toJson<int>(pageCount),
      'galleryUrl': serializer.toJson<String>(galleryUrl),
      'coverUrl': serializer.toJson<String>(coverUrl),
      'uploader': serializer.toJson<String?>(uploader),
      'size': serializer.toJson<int>(size),
      'publishTime': serializer.toJson<String>(publishTime),
      'archiveStatusCode': serializer.toJson<int>(archiveStatusCode),
      'archivePageUrl': serializer.toJson<String>(archivePageUrl),
      'downloadPageUrl': serializer.toJson<String?>(downloadPageUrl),
      'downloadUrl': serializer.toJson<String?>(downloadUrl),
      'isOriginal': serializer.toJson<bool>(isOriginal),
      'insertTime': serializer.toJson<String>(insertTime),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'groupName': serializer.toJson<String>(groupName),
      'tags': serializer.toJson<String>(tags),
      'tagRefreshTime': serializer.toJson<String?>(tagRefreshTime),
      'parseSource': serializer.toJson<int>(parseSource),
      'sanitizedTitle': serializer.toJson<String?>(sanitizedTitle),
    };
  }

  ArchiveDownloadedData copyWith({
    int? gid,
    Value<String?> copyId = const Value.absent(),
    String? token,
    String? title,
    String? category,
    int? pageCount,
    String? galleryUrl,
    String? coverUrl,
    Value<String?> uploader = const Value.absent(),
    int? size,
    String? publishTime,
    int? archiveStatusCode,
    String? archivePageUrl,
    Value<String?> downloadPageUrl = const Value.absent(),
    Value<String?> downloadUrl = const Value.absent(),
    bool? isOriginal,
    String? insertTime,
    int? sortOrder,
    String? groupName,
    String? tags,
    Value<String?> tagRefreshTime = const Value.absent(),
    int? parseSource,
    Value<String?> sanitizedTitle = const Value.absent(),
  }) => ArchiveDownloadedData(
    gid: gid ?? this.gid,
    copyId: copyId.present ? copyId.value : this.copyId,
    token: token ?? this.token,
    title: title ?? this.title,
    category: category ?? this.category,
    pageCount: pageCount ?? this.pageCount,
    galleryUrl: galleryUrl ?? this.galleryUrl,
    coverUrl: coverUrl ?? this.coverUrl,
    uploader: uploader.present ? uploader.value : this.uploader,
    size: size ?? this.size,
    publishTime: publishTime ?? this.publishTime,
    archiveStatusCode: archiveStatusCode ?? this.archiveStatusCode,
    archivePageUrl: archivePageUrl ?? this.archivePageUrl,
    downloadPageUrl: downloadPageUrl.present
        ? downloadPageUrl.value
        : this.downloadPageUrl,
    downloadUrl: downloadUrl.present ? downloadUrl.value : this.downloadUrl,
    isOriginal: isOriginal ?? this.isOriginal,
    insertTime: insertTime ?? this.insertTime,
    sortOrder: sortOrder ?? this.sortOrder,
    groupName: groupName ?? this.groupName,
    tags: tags ?? this.tags,
    tagRefreshTime: tagRefreshTime.present
        ? tagRefreshTime.value
        : this.tagRefreshTime,
    parseSource: parseSource ?? this.parseSource,
    sanitizedTitle: sanitizedTitle.present
        ? sanitizedTitle.value
        : this.sanitizedTitle,
  );
  ArchiveDownloadedData copyWithCompanion(ArchiveDownloadedCompanion data) {
    return ArchiveDownloadedData(
      gid: data.gid.present ? data.gid.value : this.gid,
      copyId: data.copyId.present ? data.copyId.value : this.copyId,
      token: data.token.present ? data.token.value : this.token,
      title: data.title.present ? data.title.value : this.title,
      category: data.category.present ? data.category.value : this.category,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      galleryUrl: data.galleryUrl.present
          ? data.galleryUrl.value
          : this.galleryUrl,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      uploader: data.uploader.present ? data.uploader.value : this.uploader,
      size: data.size.present ? data.size.value : this.size,
      publishTime: data.publishTime.present
          ? data.publishTime.value
          : this.publishTime,
      archiveStatusCode: data.archiveStatusCode.present
          ? data.archiveStatusCode.value
          : this.archiveStatusCode,
      archivePageUrl: data.archivePageUrl.present
          ? data.archivePageUrl.value
          : this.archivePageUrl,
      downloadPageUrl: data.downloadPageUrl.present
          ? data.downloadPageUrl.value
          : this.downloadPageUrl,
      downloadUrl: data.downloadUrl.present
          ? data.downloadUrl.value
          : this.downloadUrl,
      isOriginal: data.isOriginal.present
          ? data.isOriginal.value
          : this.isOriginal,
      insertTime: data.insertTime.present
          ? data.insertTime.value
          : this.insertTime,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      tags: data.tags.present ? data.tags.value : this.tags,
      tagRefreshTime: data.tagRefreshTime.present
          ? data.tagRefreshTime.value
          : this.tagRefreshTime,
      parseSource: data.parseSource.present
          ? data.parseSource.value
          : this.parseSource,
      sanitizedTitle: data.sanitizedTitle.present
          ? data.sanitizedTitle.value
          : this.sanitizedTitle,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArchiveDownloadedData(')
          ..write('gid: $gid, ')
          ..write('copyId: $copyId, ')
          ..write('token: $token, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('pageCount: $pageCount, ')
          ..write('galleryUrl: $galleryUrl, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('uploader: $uploader, ')
          ..write('size: $size, ')
          ..write('publishTime: $publishTime, ')
          ..write('archiveStatusCode: $archiveStatusCode, ')
          ..write('archivePageUrl: $archivePageUrl, ')
          ..write('downloadPageUrl: $downloadPageUrl, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('isOriginal: $isOriginal, ')
          ..write('insertTime: $insertTime, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('groupName: $groupName, ')
          ..write('tags: $tags, ')
          ..write('tagRefreshTime: $tagRefreshTime, ')
          ..write('parseSource: $parseSource, ')
          ..write('sanitizedTitle: $sanitizedTitle')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    gid,
    copyId,
    token,
    title,
    category,
    pageCount,
    galleryUrl,
    coverUrl,
    uploader,
    size,
    publishTime,
    archiveStatusCode,
    archivePageUrl,
    downloadPageUrl,
    downloadUrl,
    isOriginal,
    insertTime,
    sortOrder,
    groupName,
    tags,
    tagRefreshTime,
    parseSource,
    sanitizedTitle,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArchiveDownloadedData &&
          other.gid == this.gid &&
          other.copyId == this.copyId &&
          other.token == this.token &&
          other.title == this.title &&
          other.category == this.category &&
          other.pageCount == this.pageCount &&
          other.galleryUrl == this.galleryUrl &&
          other.coverUrl == this.coverUrl &&
          other.uploader == this.uploader &&
          other.size == this.size &&
          other.publishTime == this.publishTime &&
          other.archiveStatusCode == this.archiveStatusCode &&
          other.archivePageUrl == this.archivePageUrl &&
          other.downloadPageUrl == this.downloadPageUrl &&
          other.downloadUrl == this.downloadUrl &&
          other.isOriginal == this.isOriginal &&
          other.insertTime == this.insertTime &&
          other.sortOrder == this.sortOrder &&
          other.groupName == this.groupName &&
          other.tags == this.tags &&
          other.tagRefreshTime == this.tagRefreshTime &&
          other.parseSource == this.parseSource &&
          other.sanitizedTitle == this.sanitizedTitle);
}

class ArchiveDownloadedCompanion
    extends UpdateCompanion<ArchiveDownloadedData> {
  final Value<int> gid;
  final Value<String?> copyId;
  final Value<String> token;
  final Value<String> title;
  final Value<String> category;
  final Value<int> pageCount;
  final Value<String> galleryUrl;
  final Value<String> coverUrl;
  final Value<String?> uploader;
  final Value<int> size;
  final Value<String> publishTime;
  final Value<int> archiveStatusCode;
  final Value<String> archivePageUrl;
  final Value<String?> downloadPageUrl;
  final Value<String?> downloadUrl;
  final Value<bool> isOriginal;
  final Value<String> insertTime;
  final Value<int> sortOrder;
  final Value<String> groupName;
  final Value<String> tags;
  final Value<String?> tagRefreshTime;
  final Value<int> parseSource;
  final Value<String?> sanitizedTitle;
  const ArchiveDownloadedCompanion({
    this.gid = const Value.absent(),
    this.copyId = const Value.absent(),
    this.token = const Value.absent(),
    this.title = const Value.absent(),
    this.category = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.galleryUrl = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.uploader = const Value.absent(),
    this.size = const Value.absent(),
    this.publishTime = const Value.absent(),
    this.archiveStatusCode = const Value.absent(),
    this.archivePageUrl = const Value.absent(),
    this.downloadPageUrl = const Value.absent(),
    this.downloadUrl = const Value.absent(),
    this.isOriginal = const Value.absent(),
    this.insertTime = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.groupName = const Value.absent(),
    this.tags = const Value.absent(),
    this.tagRefreshTime = const Value.absent(),
    this.parseSource = const Value.absent(),
    this.sanitizedTitle = const Value.absent(),
  });
  ArchiveDownloadedCompanion.insert({
    this.gid = const Value.absent(),
    this.copyId = const Value.absent(),
    required String token,
    required String title,
    required String category,
    required int pageCount,
    required String galleryUrl,
    required String coverUrl,
    this.uploader = const Value.absent(),
    required int size,
    required String publishTime,
    required int archiveStatusCode,
    required String archivePageUrl,
    this.downloadPageUrl = const Value.absent(),
    this.downloadUrl = const Value.absent(),
    required bool isOriginal,
    required String insertTime,
    this.sortOrder = const Value.absent(),
    required String groupName,
    this.tags = const Value.absent(),
    this.tagRefreshTime = const Value.absent(),
    this.parseSource = const Value.absent(),
    this.sanitizedTitle = const Value.absent(),
  }) : token = Value(token),
       title = Value(title),
       category = Value(category),
       pageCount = Value(pageCount),
       galleryUrl = Value(galleryUrl),
       coverUrl = Value(coverUrl),
       size = Value(size),
       publishTime = Value(publishTime),
       archiveStatusCode = Value(archiveStatusCode),
       archivePageUrl = Value(archivePageUrl),
       isOriginal = Value(isOriginal),
       insertTime = Value(insertTime),
       groupName = Value(groupName);
  static Insertable<ArchiveDownloadedData> custom({
    Expression<int>? gid,
    Expression<String>? copyId,
    Expression<String>? token,
    Expression<String>? title,
    Expression<String>? category,
    Expression<int>? pageCount,
    Expression<String>? galleryUrl,
    Expression<String>? coverUrl,
    Expression<String>? uploader,
    Expression<int>? size,
    Expression<String>? publishTime,
    Expression<int>? archiveStatusCode,
    Expression<String>? archivePageUrl,
    Expression<String>? downloadPageUrl,
    Expression<String>? downloadUrl,
    Expression<bool>? isOriginal,
    Expression<String>? insertTime,
    Expression<int>? sortOrder,
    Expression<String>? groupName,
    Expression<String>? tags,
    Expression<String>? tagRefreshTime,
    Expression<int>? parseSource,
    Expression<String>? sanitizedTitle,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (copyId != null) 'copy_id': copyId,
      if (token != null) 'token': token,
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (pageCount != null) 'page_count': pageCount,
      if (galleryUrl != null) 'gallery_url': galleryUrl,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (uploader != null) 'uploader': uploader,
      if (size != null) 'size': size,
      if (publishTime != null) 'publish_time': publishTime,
      if (archiveStatusCode != null) 'archive_status_index': archiveStatusCode,
      if (archivePageUrl != null) 'archive_page_url': archivePageUrl,
      if (downloadPageUrl != null) 'download_page_url': downloadPageUrl,
      if (downloadUrl != null) 'download_url': downloadUrl,
      if (isOriginal != null) 'is_original': isOriginal,
      if (insertTime != null) 'insert_time': insertTime,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (groupName != null) 'group_name': groupName,
      if (tags != null) 'tags': tags,
      if (tagRefreshTime != null) 'tag_refresh_time': tagRefreshTime,
      if (parseSource != null) 'parse_source': parseSource,
      if (sanitizedTitle != null) 'sanitized_title': sanitizedTitle,
    });
  }

  ArchiveDownloadedCompanion copyWith({
    Value<int>? gid,
    Value<String?>? copyId,
    Value<String>? token,
    Value<String>? title,
    Value<String>? category,
    Value<int>? pageCount,
    Value<String>? galleryUrl,
    Value<String>? coverUrl,
    Value<String?>? uploader,
    Value<int>? size,
    Value<String>? publishTime,
    Value<int>? archiveStatusCode,
    Value<String>? archivePageUrl,
    Value<String?>? downloadPageUrl,
    Value<String?>? downloadUrl,
    Value<bool>? isOriginal,
    Value<String>? insertTime,
    Value<int>? sortOrder,
    Value<String>? groupName,
    Value<String>? tags,
    Value<String?>? tagRefreshTime,
    Value<int>? parseSource,
    Value<String?>? sanitizedTitle,
  }) {
    return ArchiveDownloadedCompanion(
      gid: gid ?? this.gid,
      copyId: copyId ?? this.copyId,
      token: token ?? this.token,
      title: title ?? this.title,
      category: category ?? this.category,
      pageCount: pageCount ?? this.pageCount,
      galleryUrl: galleryUrl ?? this.galleryUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      uploader: uploader ?? this.uploader,
      size: size ?? this.size,
      publishTime: publishTime ?? this.publishTime,
      archiveStatusCode: archiveStatusCode ?? this.archiveStatusCode,
      archivePageUrl: archivePageUrl ?? this.archivePageUrl,
      downloadPageUrl: downloadPageUrl ?? this.downloadPageUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      isOriginal: isOriginal ?? this.isOriginal,
      insertTime: insertTime ?? this.insertTime,
      sortOrder: sortOrder ?? this.sortOrder,
      groupName: groupName ?? this.groupName,
      tags: tags ?? this.tags,
      tagRefreshTime: tagRefreshTime ?? this.tagRefreshTime,
      parseSource: parseSource ?? this.parseSource,
      sanitizedTitle: sanitizedTitle ?? this.sanitizedTitle,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (copyId.present) {
      map['copy_id'] = Variable<String>(copyId.value);
    }
    if (token.present) {
      map['token'] = Variable<String>(token.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (galleryUrl.present) {
      map['gallery_url'] = Variable<String>(galleryUrl.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (uploader.present) {
      map['uploader'] = Variable<String>(uploader.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (publishTime.present) {
      map['publish_time'] = Variable<String>(publishTime.value);
    }
    if (archiveStatusCode.present) {
      map['archive_status_index'] = Variable<int>(archiveStatusCode.value);
    }
    if (archivePageUrl.present) {
      map['archive_page_url'] = Variable<String>(archivePageUrl.value);
    }
    if (downloadPageUrl.present) {
      map['download_page_url'] = Variable<String>(downloadPageUrl.value);
    }
    if (downloadUrl.present) {
      map['download_url'] = Variable<String>(downloadUrl.value);
    }
    if (isOriginal.present) {
      map['is_original'] = Variable<bool>(isOriginal.value);
    }
    if (insertTime.present) {
      map['insert_time'] = Variable<String>(insertTime.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (tagRefreshTime.present) {
      map['tag_refresh_time'] = Variable<String>(tagRefreshTime.value);
    }
    if (parseSource.present) {
      map['parse_source'] = Variable<int>(parseSource.value);
    }
    if (sanitizedTitle.present) {
      map['sanitized_title'] = Variable<String>(sanitizedTitle.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArchiveDownloadedCompanion(')
          ..write('gid: $gid, ')
          ..write('copyId: $copyId, ')
          ..write('token: $token, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('pageCount: $pageCount, ')
          ..write('galleryUrl: $galleryUrl, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('uploader: $uploader, ')
          ..write('size: $size, ')
          ..write('publishTime: $publishTime, ')
          ..write('archiveStatusCode: $archiveStatusCode, ')
          ..write('archivePageUrl: $archivePageUrl, ')
          ..write('downloadPageUrl: $downloadPageUrl, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('isOriginal: $isOriginal, ')
          ..write('insertTime: $insertTime, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('groupName: $groupName, ')
          ..write('tags: $tags, ')
          ..write('tagRefreshTime: $tagRefreshTime, ')
          ..write('parseSource: $parseSource, ')
          ..write('sanitizedTitle: $sanitizedTitle')
          ..write(')'))
        .toString();
  }
}

class $ArchiveGroupTable extends ArchiveGroup
    with TableInfo<$ArchiveGroupTable, ArchiveGroupData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArchiveGroupTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'groupName',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sortOrder',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [groupName, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'archive_group';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArchiveGroupData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('groupName')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['groupName']!, _groupNameMeta),
      );
    } else if (isInserting) {
      context.missing(_groupNameMeta);
    }
    if (data.containsKey('sortOrder')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sortOrder']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupName};
  @override
  ArchiveGroupData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArchiveGroupData(
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}groupName'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sortOrder'],
      )!,
    );
  }

  @override
  $ArchiveGroupTable createAlias(String alias) {
    return $ArchiveGroupTable(attachedDatabase, alias);
  }
}

class ArchiveGroupData extends DataClass
    implements Insertable<ArchiveGroupData> {
  final String groupName;
  final int sortOrder;
  const ArchiveGroupData({required this.groupName, required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['groupName'] = Variable<String>(groupName);
    map['sortOrder'] = Variable<int>(sortOrder);
    return map;
  }

  ArchiveGroupCompanion toCompanion(bool nullToAbsent) {
    return ArchiveGroupCompanion(
      groupName: Value(groupName),
      sortOrder: Value(sortOrder),
    );
  }

  factory ArchiveGroupData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArchiveGroupData(
      groupName: serializer.fromJson<String>(json['groupName']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupName': serializer.toJson<String>(groupName),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  ArchiveGroupData copyWith({String? groupName, int? sortOrder}) =>
      ArchiveGroupData(
        groupName: groupName ?? this.groupName,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  ArchiveGroupData copyWithCompanion(ArchiveGroupCompanion data) {
    return ArchiveGroupData(
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArchiveGroupData(')
          ..write('groupName: $groupName, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupName, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArchiveGroupData &&
          other.groupName == this.groupName &&
          other.sortOrder == this.sortOrder);
}

class ArchiveGroupCompanion extends UpdateCompanion<ArchiveGroupData> {
  final Value<String> groupName;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const ArchiveGroupCompanion({
    this.groupName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArchiveGroupCompanion.insert({
    required String groupName,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : groupName = Value(groupName);
  static Insertable<ArchiveGroupData> custom({
    Expression<String>? groupName,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupName != null) 'groupName': groupName,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArchiveGroupCompanion copyWith({
    Value<String>? groupName,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return ArchiveGroupCompanion(
      groupName: groupName ?? this.groupName,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupName.present) {
      map['groupName'] = Variable<String>(groupName.value);
    }
    if (sortOrder.present) {
      map['sortOrder'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArchiveGroupCompanion(')
          ..write('groupName: $groupName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GalleryDownloadedTable extends GalleryDownloaded
    with TableInfo<$GalleryDownloadedTable, GalleryDownloadedData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GalleryDownloadedTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
    'gid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _copyIdMeta = const VerificationMeta('copyId');
  @override
  late final GeneratedColumn<String> copyId = GeneratedColumn<String>(
    'copy_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES content_copy (copy_id)',
    ),
  );
  static const VerificationMeta _tokenMeta = const VerificationMeta('token');
  @override
  late final GeneratedColumn<String> token = GeneratedColumn<String>(
    'token',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _galleryUrlMeta = const VerificationMeta(
    'galleryUrl',
  );
  @override
  late final GeneratedColumn<String> galleryUrl = GeneratedColumn<String>(
    'gallery_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _oldVersionGalleryUrlMeta =
      const VerificationMeta('oldVersionGalleryUrl');
  @override
  late final GeneratedColumn<String> oldVersionGalleryUrl =
      GeneratedColumn<String>(
        'old_version_gallery_url',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _uploaderMeta = const VerificationMeta(
    'uploader',
  );
  @override
  late final GeneratedColumn<String> uploader = GeneratedColumn<String>(
    'uploader',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishTimeMeta = const VerificationMeta(
    'publishTime',
  );
  @override
  late final GeneratedColumn<String> publishTime = GeneratedColumn<String>(
    'publish_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadStatusIndexMeta =
      const VerificationMeta('downloadStatusIndex');
  @override
  late final GeneratedColumn<int> downloadStatusIndex = GeneratedColumn<int>(
    'download_status_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _insertTimeMeta = const VerificationMeta(
    'insertTime',
  );
  @override
  late final GeneratedColumn<String> insertTime = GeneratedColumn<String>(
    'insert_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadOriginalImageMeta =
      const VerificationMeta('downloadOriginalImage');
  @override
  late final GeneratedColumn<bool> downloadOriginalImage =
      GeneratedColumn<bool>(
        'download_original_image',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("download_original_image" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _tagRefreshTimeMeta = const VerificationMeta(
    'tagRefreshTime',
  );
  @override
  late final GeneratedColumn<String> tagRefreshTime = GeneratedColumn<String>(
    'tag_refresh_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sanitizedTitleMeta = const VerificationMeta(
    'sanitizedTitle',
  );
  @override
  late final GeneratedColumn<String> sanitizedTitle = GeneratedColumn<String>(
    'sanitized_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    gid,
    copyId,
    token,
    title,
    category,
    pageCount,
    galleryUrl,
    oldVersionGalleryUrl,
    uploader,
    publishTime,
    downloadStatusIndex,
    insertTime,
    downloadOriginalImage,
    priority,
    sortOrder,
    groupName,
    tags,
    tagRefreshTime,
    sanitizedTitle,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gallery_downloaded_v2';
  @override
  VerificationContext validateIntegrity(
    Insertable<GalleryDownloadedData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gid')) {
      context.handle(
        _gidMeta,
        gid.isAcceptableOrUnknown(data['gid']!, _gidMeta),
      );
    }
    if (data.containsKey('copy_id')) {
      context.handle(
        _copyIdMeta,
        copyId.isAcceptableOrUnknown(data['copy_id']!, _copyIdMeta),
      );
    }
    if (data.containsKey('token')) {
      context.handle(
        _tokenMeta,
        token.isAcceptableOrUnknown(data['token']!, _tokenMeta),
      );
    } else if (isInserting) {
      context.missing(_tokenMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    } else if (isInserting) {
      context.missing(_pageCountMeta);
    }
    if (data.containsKey('gallery_url')) {
      context.handle(
        _galleryUrlMeta,
        galleryUrl.isAcceptableOrUnknown(data['gallery_url']!, _galleryUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_galleryUrlMeta);
    }
    if (data.containsKey('old_version_gallery_url')) {
      context.handle(
        _oldVersionGalleryUrlMeta,
        oldVersionGalleryUrl.isAcceptableOrUnknown(
          data['old_version_gallery_url']!,
          _oldVersionGalleryUrlMeta,
        ),
      );
    }
    if (data.containsKey('uploader')) {
      context.handle(
        _uploaderMeta,
        uploader.isAcceptableOrUnknown(data['uploader']!, _uploaderMeta),
      );
    }
    if (data.containsKey('publish_time')) {
      context.handle(
        _publishTimeMeta,
        publishTime.isAcceptableOrUnknown(
          data['publish_time']!,
          _publishTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publishTimeMeta);
    }
    if (data.containsKey('download_status_index')) {
      context.handle(
        _downloadStatusIndexMeta,
        downloadStatusIndex.isAcceptableOrUnknown(
          data['download_status_index']!,
          _downloadStatusIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_downloadStatusIndexMeta);
    }
    if (data.containsKey('insert_time')) {
      context.handle(
        _insertTimeMeta,
        insertTime.isAcceptableOrUnknown(data['insert_time']!, _insertTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_insertTimeMeta);
    }
    if (data.containsKey('download_original_image')) {
      context.handle(
        _downloadOriginalImageMeta,
        downloadOriginalImage.isAcceptableOrUnknown(
          data['download_original_image']!,
          _downloadOriginalImageMeta,
        ),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    } else if (isInserting) {
      context.missing(_groupNameMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('tag_refresh_time')) {
      context.handle(
        _tagRefreshTimeMeta,
        tagRefreshTime.isAcceptableOrUnknown(
          data['tag_refresh_time']!,
          _tagRefreshTimeMeta,
        ),
      );
    }
    if (data.containsKey('sanitized_title')) {
      context.handle(
        _sanitizedTitleMeta,
        sanitizedTitle.isAcceptableOrUnknown(
          data['sanitized_title']!,
          _sanitizedTitleMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid};
  @override
  GalleryDownloadedData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryDownloadedData(
      gid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gid'],
      )!,
      copyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}copy_id'],
      ),
      token: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      galleryUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gallery_url'],
      )!,
      oldVersionGalleryUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_version_gallery_url'],
      ),
      uploader: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uploader'],
      ),
      publishTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publish_time'],
      )!,
      downloadStatusIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}download_status_index'],
      )!,
      insertTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}insert_time'],
      )!,
      downloadOriginalImage: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}download_original_image'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      tagRefreshTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_refresh_time'],
      ),
      sanitizedTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sanitized_title'],
      ),
    );
  }

  @override
  $GalleryDownloadedTable createAlias(String alias) {
    return $GalleryDownloadedTable(attachedDatabase, alias);
  }
}

class GalleryDownloadedData extends DataClass
    implements Insertable<GalleryDownloadedData> {
  final int gid;
  final String? copyId;
  final String token;
  final String title;
  final String category;
  final int pageCount;
  final String galleryUrl;
  final String? oldVersionGalleryUrl;
  final String? uploader;
  final String publishTime;
  final int downloadStatusIndex;
  final String insertTime;
  final bool downloadOriginalImage;
  final int priority;
  final int sortOrder;
  final String groupName;
  final String tags;
  final String? tagRefreshTime;

  /// Sanitized and truncated title used as the directory name on disk.
  /// Computed once when the download task is first created and stored here to
  /// ensure the path never changes even if the truncation algorithm is updated.
  final String? sanitizedTitle;
  const GalleryDownloadedData({
    required this.gid,
    this.copyId,
    required this.token,
    required this.title,
    required this.category,
    required this.pageCount,
    required this.galleryUrl,
    this.oldVersionGalleryUrl,
    this.uploader,
    required this.publishTime,
    required this.downloadStatusIndex,
    required this.insertTime,
    required this.downloadOriginalImage,
    required this.priority,
    required this.sortOrder,
    required this.groupName,
    required this.tags,
    this.tagRefreshTime,
    this.sanitizedTitle,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gid'] = Variable<int>(gid);
    if (!nullToAbsent || copyId != null) {
      map['copy_id'] = Variable<String>(copyId);
    }
    map['token'] = Variable<String>(token);
    map['title'] = Variable<String>(title);
    map['category'] = Variable<String>(category);
    map['page_count'] = Variable<int>(pageCount);
    map['gallery_url'] = Variable<String>(galleryUrl);
    if (!nullToAbsent || oldVersionGalleryUrl != null) {
      map['old_version_gallery_url'] = Variable<String>(oldVersionGalleryUrl);
    }
    if (!nullToAbsent || uploader != null) {
      map['uploader'] = Variable<String>(uploader);
    }
    map['publish_time'] = Variable<String>(publishTime);
    map['download_status_index'] = Variable<int>(downloadStatusIndex);
    map['insert_time'] = Variable<String>(insertTime);
    map['download_original_image'] = Variable<bool>(downloadOriginalImage);
    map['priority'] = Variable<int>(priority);
    map['sort_order'] = Variable<int>(sortOrder);
    map['group_name'] = Variable<String>(groupName);
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || tagRefreshTime != null) {
      map['tag_refresh_time'] = Variable<String>(tagRefreshTime);
    }
    if (!nullToAbsent || sanitizedTitle != null) {
      map['sanitized_title'] = Variable<String>(sanitizedTitle);
    }
    return map;
  }

  GalleryDownloadedCompanion toCompanion(bool nullToAbsent) {
    return GalleryDownloadedCompanion(
      gid: Value(gid),
      copyId: copyId == null && nullToAbsent
          ? const Value.absent()
          : Value(copyId),
      token: Value(token),
      title: Value(title),
      category: Value(category),
      pageCount: Value(pageCount),
      galleryUrl: Value(galleryUrl),
      oldVersionGalleryUrl: oldVersionGalleryUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(oldVersionGalleryUrl),
      uploader: uploader == null && nullToAbsent
          ? const Value.absent()
          : Value(uploader),
      publishTime: Value(publishTime),
      downloadStatusIndex: Value(downloadStatusIndex),
      insertTime: Value(insertTime),
      downloadOriginalImage: Value(downloadOriginalImage),
      priority: Value(priority),
      sortOrder: Value(sortOrder),
      groupName: Value(groupName),
      tags: Value(tags),
      tagRefreshTime: tagRefreshTime == null && nullToAbsent
          ? const Value.absent()
          : Value(tagRefreshTime),
      sanitizedTitle: sanitizedTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(sanitizedTitle),
    );
  }

  factory GalleryDownloadedData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryDownloadedData(
      gid: serializer.fromJson<int>(json['gid']),
      copyId: serializer.fromJson<String?>(json['copyId']),
      token: serializer.fromJson<String>(json['token']),
      title: serializer.fromJson<String>(json['title']),
      category: serializer.fromJson<String>(json['category']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      galleryUrl: serializer.fromJson<String>(json['galleryUrl']),
      oldVersionGalleryUrl: serializer.fromJson<String?>(
        json['oldVersionGalleryUrl'],
      ),
      uploader: serializer.fromJson<String?>(json['uploader']),
      publishTime: serializer.fromJson<String>(json['publishTime']),
      downloadStatusIndex: serializer.fromJson<int>(
        json['downloadStatusIndex'],
      ),
      insertTime: serializer.fromJson<String>(json['insertTime']),
      downloadOriginalImage: serializer.fromJson<bool>(
        json['downloadOriginalImage'],
      ),
      priority: serializer.fromJson<int>(json['priority']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      groupName: serializer.fromJson<String>(json['groupName']),
      tags: serializer.fromJson<String>(json['tags']),
      tagRefreshTime: serializer.fromJson<String?>(json['tagRefreshTime']),
      sanitizedTitle: serializer.fromJson<String?>(json['sanitizedTitle']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gid': serializer.toJson<int>(gid),
      'copyId': serializer.toJson<String?>(copyId),
      'token': serializer.toJson<String>(token),
      'title': serializer.toJson<String>(title),
      'category': serializer.toJson<String>(category),
      'pageCount': serializer.toJson<int>(pageCount),
      'galleryUrl': serializer.toJson<String>(galleryUrl),
      'oldVersionGalleryUrl': serializer.toJson<String?>(oldVersionGalleryUrl),
      'uploader': serializer.toJson<String?>(uploader),
      'publishTime': serializer.toJson<String>(publishTime),
      'downloadStatusIndex': serializer.toJson<int>(downloadStatusIndex),
      'insertTime': serializer.toJson<String>(insertTime),
      'downloadOriginalImage': serializer.toJson<bool>(downloadOriginalImage),
      'priority': serializer.toJson<int>(priority),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'groupName': serializer.toJson<String>(groupName),
      'tags': serializer.toJson<String>(tags),
      'tagRefreshTime': serializer.toJson<String?>(tagRefreshTime),
      'sanitizedTitle': serializer.toJson<String?>(sanitizedTitle),
    };
  }

  GalleryDownloadedData copyWith({
    int? gid,
    Value<String?> copyId = const Value.absent(),
    String? token,
    String? title,
    String? category,
    int? pageCount,
    String? galleryUrl,
    Value<String?> oldVersionGalleryUrl = const Value.absent(),
    Value<String?> uploader = const Value.absent(),
    String? publishTime,
    int? downloadStatusIndex,
    String? insertTime,
    bool? downloadOriginalImage,
    int? priority,
    int? sortOrder,
    String? groupName,
    String? tags,
    Value<String?> tagRefreshTime = const Value.absent(),
    Value<String?> sanitizedTitle = const Value.absent(),
  }) => GalleryDownloadedData(
    gid: gid ?? this.gid,
    copyId: copyId.present ? copyId.value : this.copyId,
    token: token ?? this.token,
    title: title ?? this.title,
    category: category ?? this.category,
    pageCount: pageCount ?? this.pageCount,
    galleryUrl: galleryUrl ?? this.galleryUrl,
    oldVersionGalleryUrl: oldVersionGalleryUrl.present
        ? oldVersionGalleryUrl.value
        : this.oldVersionGalleryUrl,
    uploader: uploader.present ? uploader.value : this.uploader,
    publishTime: publishTime ?? this.publishTime,
    downloadStatusIndex: downloadStatusIndex ?? this.downloadStatusIndex,
    insertTime: insertTime ?? this.insertTime,
    downloadOriginalImage: downloadOriginalImage ?? this.downloadOriginalImage,
    priority: priority ?? this.priority,
    sortOrder: sortOrder ?? this.sortOrder,
    groupName: groupName ?? this.groupName,
    tags: tags ?? this.tags,
    tagRefreshTime: tagRefreshTime.present
        ? tagRefreshTime.value
        : this.tagRefreshTime,
    sanitizedTitle: sanitizedTitle.present
        ? sanitizedTitle.value
        : this.sanitizedTitle,
  );
  GalleryDownloadedData copyWithCompanion(GalleryDownloadedCompanion data) {
    return GalleryDownloadedData(
      gid: data.gid.present ? data.gid.value : this.gid,
      copyId: data.copyId.present ? data.copyId.value : this.copyId,
      token: data.token.present ? data.token.value : this.token,
      title: data.title.present ? data.title.value : this.title,
      category: data.category.present ? data.category.value : this.category,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      galleryUrl: data.galleryUrl.present
          ? data.galleryUrl.value
          : this.galleryUrl,
      oldVersionGalleryUrl: data.oldVersionGalleryUrl.present
          ? data.oldVersionGalleryUrl.value
          : this.oldVersionGalleryUrl,
      uploader: data.uploader.present ? data.uploader.value : this.uploader,
      publishTime: data.publishTime.present
          ? data.publishTime.value
          : this.publishTime,
      downloadStatusIndex: data.downloadStatusIndex.present
          ? data.downloadStatusIndex.value
          : this.downloadStatusIndex,
      insertTime: data.insertTime.present
          ? data.insertTime.value
          : this.insertTime,
      downloadOriginalImage: data.downloadOriginalImage.present
          ? data.downloadOriginalImage.value
          : this.downloadOriginalImage,
      priority: data.priority.present ? data.priority.value : this.priority,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      tags: data.tags.present ? data.tags.value : this.tags,
      tagRefreshTime: data.tagRefreshTime.present
          ? data.tagRefreshTime.value
          : this.tagRefreshTime,
      sanitizedTitle: data.sanitizedTitle.present
          ? data.sanitizedTitle.value
          : this.sanitizedTitle,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GalleryDownloadedData(')
          ..write('gid: $gid, ')
          ..write('copyId: $copyId, ')
          ..write('token: $token, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('pageCount: $pageCount, ')
          ..write('galleryUrl: $galleryUrl, ')
          ..write('oldVersionGalleryUrl: $oldVersionGalleryUrl, ')
          ..write('uploader: $uploader, ')
          ..write('publishTime: $publishTime, ')
          ..write('downloadStatusIndex: $downloadStatusIndex, ')
          ..write('insertTime: $insertTime, ')
          ..write('downloadOriginalImage: $downloadOriginalImage, ')
          ..write('priority: $priority, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('groupName: $groupName, ')
          ..write('tags: $tags, ')
          ..write('tagRefreshTime: $tagRefreshTime, ')
          ..write('sanitizedTitle: $sanitizedTitle')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    gid,
    copyId,
    token,
    title,
    category,
    pageCount,
    galleryUrl,
    oldVersionGalleryUrl,
    uploader,
    publishTime,
    downloadStatusIndex,
    insertTime,
    downloadOriginalImage,
    priority,
    sortOrder,
    groupName,
    tags,
    tagRefreshTime,
    sanitizedTitle,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryDownloadedData &&
          other.gid == this.gid &&
          other.copyId == this.copyId &&
          other.token == this.token &&
          other.title == this.title &&
          other.category == this.category &&
          other.pageCount == this.pageCount &&
          other.galleryUrl == this.galleryUrl &&
          other.oldVersionGalleryUrl == this.oldVersionGalleryUrl &&
          other.uploader == this.uploader &&
          other.publishTime == this.publishTime &&
          other.downloadStatusIndex == this.downloadStatusIndex &&
          other.insertTime == this.insertTime &&
          other.downloadOriginalImage == this.downloadOriginalImage &&
          other.priority == this.priority &&
          other.sortOrder == this.sortOrder &&
          other.groupName == this.groupName &&
          other.tags == this.tags &&
          other.tagRefreshTime == this.tagRefreshTime &&
          other.sanitizedTitle == this.sanitizedTitle);
}

class GalleryDownloadedCompanion
    extends UpdateCompanion<GalleryDownloadedData> {
  final Value<int> gid;
  final Value<String?> copyId;
  final Value<String> token;
  final Value<String> title;
  final Value<String> category;
  final Value<int> pageCount;
  final Value<String> galleryUrl;
  final Value<String?> oldVersionGalleryUrl;
  final Value<String?> uploader;
  final Value<String> publishTime;
  final Value<int> downloadStatusIndex;
  final Value<String> insertTime;
  final Value<bool> downloadOriginalImage;
  final Value<int> priority;
  final Value<int> sortOrder;
  final Value<String> groupName;
  final Value<String> tags;
  final Value<String?> tagRefreshTime;
  final Value<String?> sanitizedTitle;
  const GalleryDownloadedCompanion({
    this.gid = const Value.absent(),
    this.copyId = const Value.absent(),
    this.token = const Value.absent(),
    this.title = const Value.absent(),
    this.category = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.galleryUrl = const Value.absent(),
    this.oldVersionGalleryUrl = const Value.absent(),
    this.uploader = const Value.absent(),
    this.publishTime = const Value.absent(),
    this.downloadStatusIndex = const Value.absent(),
    this.insertTime = const Value.absent(),
    this.downloadOriginalImage = const Value.absent(),
    this.priority = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.groupName = const Value.absent(),
    this.tags = const Value.absent(),
    this.tagRefreshTime = const Value.absent(),
    this.sanitizedTitle = const Value.absent(),
  });
  GalleryDownloadedCompanion.insert({
    this.gid = const Value.absent(),
    this.copyId = const Value.absent(),
    required String token,
    required String title,
    required String category,
    required int pageCount,
    required String galleryUrl,
    this.oldVersionGalleryUrl = const Value.absent(),
    this.uploader = const Value.absent(),
    required String publishTime,
    required int downloadStatusIndex,
    required String insertTime,
    this.downloadOriginalImage = const Value.absent(),
    required int priority,
    this.sortOrder = const Value.absent(),
    required String groupName,
    this.tags = const Value.absent(),
    this.tagRefreshTime = const Value.absent(),
    this.sanitizedTitle = const Value.absent(),
  }) : token = Value(token),
       title = Value(title),
       category = Value(category),
       pageCount = Value(pageCount),
       galleryUrl = Value(galleryUrl),
       publishTime = Value(publishTime),
       downloadStatusIndex = Value(downloadStatusIndex),
       insertTime = Value(insertTime),
       priority = Value(priority),
       groupName = Value(groupName);
  static Insertable<GalleryDownloadedData> custom({
    Expression<int>? gid,
    Expression<String>? copyId,
    Expression<String>? token,
    Expression<String>? title,
    Expression<String>? category,
    Expression<int>? pageCount,
    Expression<String>? galleryUrl,
    Expression<String>? oldVersionGalleryUrl,
    Expression<String>? uploader,
    Expression<String>? publishTime,
    Expression<int>? downloadStatusIndex,
    Expression<String>? insertTime,
    Expression<bool>? downloadOriginalImage,
    Expression<int>? priority,
    Expression<int>? sortOrder,
    Expression<String>? groupName,
    Expression<String>? tags,
    Expression<String>? tagRefreshTime,
    Expression<String>? sanitizedTitle,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (copyId != null) 'copy_id': copyId,
      if (token != null) 'token': token,
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (pageCount != null) 'page_count': pageCount,
      if (galleryUrl != null) 'gallery_url': galleryUrl,
      if (oldVersionGalleryUrl != null)
        'old_version_gallery_url': oldVersionGalleryUrl,
      if (uploader != null) 'uploader': uploader,
      if (publishTime != null) 'publish_time': publishTime,
      if (downloadStatusIndex != null)
        'download_status_index': downloadStatusIndex,
      if (insertTime != null) 'insert_time': insertTime,
      if (downloadOriginalImage != null)
        'download_original_image': downloadOriginalImage,
      if (priority != null) 'priority': priority,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (groupName != null) 'group_name': groupName,
      if (tags != null) 'tags': tags,
      if (tagRefreshTime != null) 'tag_refresh_time': tagRefreshTime,
      if (sanitizedTitle != null) 'sanitized_title': sanitizedTitle,
    });
  }

  GalleryDownloadedCompanion copyWith({
    Value<int>? gid,
    Value<String?>? copyId,
    Value<String>? token,
    Value<String>? title,
    Value<String>? category,
    Value<int>? pageCount,
    Value<String>? galleryUrl,
    Value<String?>? oldVersionGalleryUrl,
    Value<String?>? uploader,
    Value<String>? publishTime,
    Value<int>? downloadStatusIndex,
    Value<String>? insertTime,
    Value<bool>? downloadOriginalImage,
    Value<int>? priority,
    Value<int>? sortOrder,
    Value<String>? groupName,
    Value<String>? tags,
    Value<String?>? tagRefreshTime,
    Value<String?>? sanitizedTitle,
  }) {
    return GalleryDownloadedCompanion(
      gid: gid ?? this.gid,
      copyId: copyId ?? this.copyId,
      token: token ?? this.token,
      title: title ?? this.title,
      category: category ?? this.category,
      pageCount: pageCount ?? this.pageCount,
      galleryUrl: galleryUrl ?? this.galleryUrl,
      oldVersionGalleryUrl: oldVersionGalleryUrl ?? this.oldVersionGalleryUrl,
      uploader: uploader ?? this.uploader,
      publishTime: publishTime ?? this.publishTime,
      downloadStatusIndex: downloadStatusIndex ?? this.downloadStatusIndex,
      insertTime: insertTime ?? this.insertTime,
      downloadOriginalImage:
          downloadOriginalImage ?? this.downloadOriginalImage,
      priority: priority ?? this.priority,
      sortOrder: sortOrder ?? this.sortOrder,
      groupName: groupName ?? this.groupName,
      tags: tags ?? this.tags,
      tagRefreshTime: tagRefreshTime ?? this.tagRefreshTime,
      sanitizedTitle: sanitizedTitle ?? this.sanitizedTitle,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (copyId.present) {
      map['copy_id'] = Variable<String>(copyId.value);
    }
    if (token.present) {
      map['token'] = Variable<String>(token.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (galleryUrl.present) {
      map['gallery_url'] = Variable<String>(galleryUrl.value);
    }
    if (oldVersionGalleryUrl.present) {
      map['old_version_gallery_url'] = Variable<String>(
        oldVersionGalleryUrl.value,
      );
    }
    if (uploader.present) {
      map['uploader'] = Variable<String>(uploader.value);
    }
    if (publishTime.present) {
      map['publish_time'] = Variable<String>(publishTime.value);
    }
    if (downloadStatusIndex.present) {
      map['download_status_index'] = Variable<int>(downloadStatusIndex.value);
    }
    if (insertTime.present) {
      map['insert_time'] = Variable<String>(insertTime.value);
    }
    if (downloadOriginalImage.present) {
      map['download_original_image'] = Variable<bool>(
        downloadOriginalImage.value,
      );
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (tagRefreshTime.present) {
      map['tag_refresh_time'] = Variable<String>(tagRefreshTime.value);
    }
    if (sanitizedTitle.present) {
      map['sanitized_title'] = Variable<String>(sanitizedTitle.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryDownloadedCompanion(')
          ..write('gid: $gid, ')
          ..write('copyId: $copyId, ')
          ..write('token: $token, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('pageCount: $pageCount, ')
          ..write('galleryUrl: $galleryUrl, ')
          ..write('oldVersionGalleryUrl: $oldVersionGalleryUrl, ')
          ..write('uploader: $uploader, ')
          ..write('publishTime: $publishTime, ')
          ..write('downloadStatusIndex: $downloadStatusIndex, ')
          ..write('insertTime: $insertTime, ')
          ..write('downloadOriginalImage: $downloadOriginalImage, ')
          ..write('priority: $priority, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('groupName: $groupName, ')
          ..write('tags: $tags, ')
          ..write('tagRefreshTime: $tagRefreshTime, ')
          ..write('sanitizedTitle: $sanitizedTitle')
          ..write(')'))
        .toString();
  }
}

class $GalleryGroupTable extends GalleryGroup
    with TableInfo<$GalleryGroupTable, GalleryGroupData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GalleryGroupTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'groupName',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sortOrder',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [groupName, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gallery_group';
  @override
  VerificationContext validateIntegrity(
    Insertable<GalleryGroupData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('groupName')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['groupName']!, _groupNameMeta),
      );
    } else if (isInserting) {
      context.missing(_groupNameMeta);
    }
    if (data.containsKey('sortOrder')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sortOrder']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupName};
  @override
  GalleryGroupData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryGroupData(
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}groupName'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sortOrder'],
      )!,
    );
  }

  @override
  $GalleryGroupTable createAlias(String alias) {
    return $GalleryGroupTable(attachedDatabase, alias);
  }
}

class GalleryGroupData extends DataClass
    implements Insertable<GalleryGroupData> {
  final String groupName;
  final int sortOrder;
  const GalleryGroupData({required this.groupName, required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['groupName'] = Variable<String>(groupName);
    map['sortOrder'] = Variable<int>(sortOrder);
    return map;
  }

  GalleryGroupCompanion toCompanion(bool nullToAbsent) {
    return GalleryGroupCompanion(
      groupName: Value(groupName),
      sortOrder: Value(sortOrder),
    );
  }

  factory GalleryGroupData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryGroupData(
      groupName: serializer.fromJson<String>(json['groupName']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupName': serializer.toJson<String>(groupName),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  GalleryGroupData copyWith({String? groupName, int? sortOrder}) =>
      GalleryGroupData(
        groupName: groupName ?? this.groupName,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  GalleryGroupData copyWithCompanion(GalleryGroupCompanion data) {
    return GalleryGroupData(
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GalleryGroupData(')
          ..write('groupName: $groupName, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupName, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryGroupData &&
          other.groupName == this.groupName &&
          other.sortOrder == this.sortOrder);
}

class GalleryGroupCompanion extends UpdateCompanion<GalleryGroupData> {
  final Value<String> groupName;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const GalleryGroupCompanion({
    this.groupName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GalleryGroupCompanion.insert({
    required String groupName,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : groupName = Value(groupName);
  static Insertable<GalleryGroupData> custom({
    Expression<String>? groupName,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupName != null) 'groupName': groupName,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GalleryGroupCompanion copyWith({
    Value<String>? groupName,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return GalleryGroupCompanion(
      groupName: groupName ?? this.groupName,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupName.present) {
      map['groupName'] = Variable<String>(groupName.value);
    }
    if (sortOrder.present) {
      map['sortOrder'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryGroupCompanion(')
          ..write('groupName: $groupName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImageTable extends Image with TableInfo<$ImageTable, ImageData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImageTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
    'gid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES gallery_downloaded_v2 (gid)',
    ),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalImageUrlMeta = const VerificationMeta(
    'originalImageUrl',
  );
  @override
  late final GeneratedColumn<String> originalImageUrl = GeneratedColumn<String>(
    'originalImageUrl',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serialNoMeta = const VerificationMeta(
    'serialNo',
  );
  @override
  late final GeneratedColumn<int> serialNo = GeneratedColumn<int>(
    'serialNo',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageHashMeta = const VerificationMeta(
    'imageHash',
  );
  @override
  late final GeneratedColumn<String> imageHash = GeneratedColumn<String>(
    'imageHash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadStatusIndexMeta =
      const VerificationMeta('downloadStatusIndex');
  @override
  late final GeneratedColumn<int> downloadStatusIndex = GeneratedColumn<int>(
    'downloadStatusIndex',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    gid,
    url,
    originalImageUrl,
    serialNo,
    path,
    imageHash,
    downloadStatusIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'image';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImageData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gid')) {
      context.handle(
        _gidMeta,
        gid.isAcceptableOrUnknown(data['gid']!, _gidMeta),
      );
    } else if (isInserting) {
      context.missing(_gidMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('originalImageUrl')) {
      context.handle(
        _originalImageUrlMeta,
        originalImageUrl.isAcceptableOrUnknown(
          data['originalImageUrl']!,
          _originalImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('serialNo')) {
      context.handle(
        _serialNoMeta,
        serialNo.isAcceptableOrUnknown(data['serialNo']!, _serialNoMeta),
      );
    } else if (isInserting) {
      context.missing(_serialNoMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('imageHash')) {
      context.handle(
        _imageHashMeta,
        imageHash.isAcceptableOrUnknown(data['imageHash']!, _imageHashMeta),
      );
    } else if (isInserting) {
      context.missing(_imageHashMeta);
    }
    if (data.containsKey('downloadStatusIndex')) {
      context.handle(
        _downloadStatusIndexMeta,
        downloadStatusIndex.isAcceptableOrUnknown(
          data['downloadStatusIndex']!,
          _downloadStatusIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_downloadStatusIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid, serialNo};
  @override
  ImageData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImageData(
      gid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gid'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      originalImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}originalImageUrl'],
      ),
      serialNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}serialNo'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      imageHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imageHash'],
      )!,
      downloadStatusIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloadStatusIndex'],
      )!,
    );
  }

  @override
  $ImageTable createAlias(String alias) {
    return $ImageTable(attachedDatabase, alias);
  }
}

class ImageData extends DataClass implements Insertable<ImageData> {
  final int gid;
  final String url;

  /// Original (full-size) image URL. Null for galleries downloaded without
  /// `downloadOriginalImage`, or for legacy rows written before this column
  /// existed — runtime falls back to `url` via
  /// `_downloadUrlFor` in gallery_download_service.dart.
  final String? originalImageUrl;
  final int serialNo;
  final String path;
  final String imageHash;
  final int downloadStatusIndex;
  const ImageData({
    required this.gid,
    required this.url,
    this.originalImageUrl,
    required this.serialNo,
    required this.path,
    required this.imageHash,
    required this.downloadStatusIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gid'] = Variable<int>(gid);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || originalImageUrl != null) {
      map['originalImageUrl'] = Variable<String>(originalImageUrl);
    }
    map['serialNo'] = Variable<int>(serialNo);
    map['path'] = Variable<String>(path);
    map['imageHash'] = Variable<String>(imageHash);
    map['downloadStatusIndex'] = Variable<int>(downloadStatusIndex);
    return map;
  }

  ImageCompanion toCompanion(bool nullToAbsent) {
    return ImageCompanion(
      gid: Value(gid),
      url: Value(url),
      originalImageUrl: originalImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(originalImageUrl),
      serialNo: Value(serialNo),
      path: Value(path),
      imageHash: Value(imageHash),
      downloadStatusIndex: Value(downloadStatusIndex),
    );
  }

  factory ImageData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImageData(
      gid: serializer.fromJson<int>(json['gid']),
      url: serializer.fromJson<String>(json['url']),
      originalImageUrl: serializer.fromJson<String?>(json['originalImageUrl']),
      serialNo: serializer.fromJson<int>(json['serialNo']),
      path: serializer.fromJson<String>(json['path']),
      imageHash: serializer.fromJson<String>(json['imageHash']),
      downloadStatusIndex: serializer.fromJson<int>(
        json['downloadStatusIndex'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gid': serializer.toJson<int>(gid),
      'url': serializer.toJson<String>(url),
      'originalImageUrl': serializer.toJson<String?>(originalImageUrl),
      'serialNo': serializer.toJson<int>(serialNo),
      'path': serializer.toJson<String>(path),
      'imageHash': serializer.toJson<String>(imageHash),
      'downloadStatusIndex': serializer.toJson<int>(downloadStatusIndex),
    };
  }

  ImageData copyWith({
    int? gid,
    String? url,
    Value<String?> originalImageUrl = const Value.absent(),
    int? serialNo,
    String? path,
    String? imageHash,
    int? downloadStatusIndex,
  }) => ImageData(
    gid: gid ?? this.gid,
    url: url ?? this.url,
    originalImageUrl: originalImageUrl.present
        ? originalImageUrl.value
        : this.originalImageUrl,
    serialNo: serialNo ?? this.serialNo,
    path: path ?? this.path,
    imageHash: imageHash ?? this.imageHash,
    downloadStatusIndex: downloadStatusIndex ?? this.downloadStatusIndex,
  );
  ImageData copyWithCompanion(ImageCompanion data) {
    return ImageData(
      gid: data.gid.present ? data.gid.value : this.gid,
      url: data.url.present ? data.url.value : this.url,
      originalImageUrl: data.originalImageUrl.present
          ? data.originalImageUrl.value
          : this.originalImageUrl,
      serialNo: data.serialNo.present ? data.serialNo.value : this.serialNo,
      path: data.path.present ? data.path.value : this.path,
      imageHash: data.imageHash.present ? data.imageHash.value : this.imageHash,
      downloadStatusIndex: data.downloadStatusIndex.present
          ? data.downloadStatusIndex.value
          : this.downloadStatusIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImageData(')
          ..write('gid: $gid, ')
          ..write('url: $url, ')
          ..write('originalImageUrl: $originalImageUrl, ')
          ..write('serialNo: $serialNo, ')
          ..write('path: $path, ')
          ..write('imageHash: $imageHash, ')
          ..write('downloadStatusIndex: $downloadStatusIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    gid,
    url,
    originalImageUrl,
    serialNo,
    path,
    imageHash,
    downloadStatusIndex,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageData &&
          other.gid == this.gid &&
          other.url == this.url &&
          other.originalImageUrl == this.originalImageUrl &&
          other.serialNo == this.serialNo &&
          other.path == this.path &&
          other.imageHash == this.imageHash &&
          other.downloadStatusIndex == this.downloadStatusIndex);
}

class ImageCompanion extends UpdateCompanion<ImageData> {
  final Value<int> gid;
  final Value<String> url;
  final Value<String?> originalImageUrl;
  final Value<int> serialNo;
  final Value<String> path;
  final Value<String> imageHash;
  final Value<int> downloadStatusIndex;
  final Value<int> rowid;
  const ImageCompanion({
    this.gid = const Value.absent(),
    this.url = const Value.absent(),
    this.originalImageUrl = const Value.absent(),
    this.serialNo = const Value.absent(),
    this.path = const Value.absent(),
    this.imageHash = const Value.absent(),
    this.downloadStatusIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImageCompanion.insert({
    required int gid,
    required String url,
    this.originalImageUrl = const Value.absent(),
    required int serialNo,
    required String path,
    required String imageHash,
    required int downloadStatusIndex,
    this.rowid = const Value.absent(),
  }) : gid = Value(gid),
       url = Value(url),
       serialNo = Value(serialNo),
       path = Value(path),
       imageHash = Value(imageHash),
       downloadStatusIndex = Value(downloadStatusIndex);
  static Insertable<ImageData> custom({
    Expression<int>? gid,
    Expression<String>? url,
    Expression<String>? originalImageUrl,
    Expression<int>? serialNo,
    Expression<String>? path,
    Expression<String>? imageHash,
    Expression<int>? downloadStatusIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (url != null) 'url': url,
      if (originalImageUrl != null) 'originalImageUrl': originalImageUrl,
      if (serialNo != null) 'serialNo': serialNo,
      if (path != null) 'path': path,
      if (imageHash != null) 'imageHash': imageHash,
      if (downloadStatusIndex != null)
        'downloadStatusIndex': downloadStatusIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImageCompanion copyWith({
    Value<int>? gid,
    Value<String>? url,
    Value<String?>? originalImageUrl,
    Value<int>? serialNo,
    Value<String>? path,
    Value<String>? imageHash,
    Value<int>? downloadStatusIndex,
    Value<int>? rowid,
  }) {
    return ImageCompanion(
      gid: gid ?? this.gid,
      url: url ?? this.url,
      originalImageUrl: originalImageUrl ?? this.originalImageUrl,
      serialNo: serialNo ?? this.serialNo,
      path: path ?? this.path,
      imageHash: imageHash ?? this.imageHash,
      downloadStatusIndex: downloadStatusIndex ?? this.downloadStatusIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (originalImageUrl.present) {
      map['originalImageUrl'] = Variable<String>(originalImageUrl.value);
    }
    if (serialNo.present) {
      map['serialNo'] = Variable<int>(serialNo.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (imageHash.present) {
      map['imageHash'] = Variable<String>(imageHash.value);
    }
    if (downloadStatusIndex.present) {
      map['downloadStatusIndex'] = Variable<int>(downloadStatusIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImageCompanion(')
          ..write('gid: $gid, ')
          ..write('url: $url, ')
          ..write('originalImageUrl: $originalImageUrl, ')
          ..write('serialNo: $serialNo, ')
          ..write('path: $path, ')
          ..write('imageHash: $imageHash, ')
          ..write('downloadStatusIndex: $downloadStatusIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GalleryHistoryV2Table extends GalleryHistoryV2
    with TableInfo<$GalleryHistoryV2Table, GalleryHistoryV2Data> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GalleryHistoryV2Table(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
    'gid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _jsonBodyMeta = const VerificationMeta(
    'jsonBody',
  );
  @override
  late final GeneratedColumn<String> jsonBody = GeneratedColumn<String>(
    'jsonBody',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastReadTimeMeta = const VerificationMeta(
    'lastReadTime',
  );
  @override
  late final GeneratedColumn<String> lastReadTime = GeneratedColumn<String>(
    'lastReadTime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [gid, jsonBody, lastReadTime];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gallery_history_v2';
  @override
  VerificationContext validateIntegrity(
    Insertable<GalleryHistoryV2Data> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gid')) {
      context.handle(
        _gidMeta,
        gid.isAcceptableOrUnknown(data['gid']!, _gidMeta),
      );
    }
    if (data.containsKey('jsonBody')) {
      context.handle(
        _jsonBodyMeta,
        jsonBody.isAcceptableOrUnknown(data['jsonBody']!, _jsonBodyMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonBodyMeta);
    }
    if (data.containsKey('lastReadTime')) {
      context.handle(
        _lastReadTimeMeta,
        lastReadTime.isAcceptableOrUnknown(
          data['lastReadTime']!,
          _lastReadTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastReadTimeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid};
  @override
  GalleryHistoryV2Data map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryHistoryV2Data(
      gid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gid'],
      )!,
      jsonBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jsonBody'],
      )!,
      lastReadTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lastReadTime'],
      )!,
    );
  }

  @override
  $GalleryHistoryV2Table createAlias(String alias) {
    return $GalleryHistoryV2Table(attachedDatabase, alias);
  }
}

class GalleryHistoryV2Data extends DataClass
    implements Insertable<GalleryHistoryV2Data> {
  final int gid;
  final String jsonBody;
  final String lastReadTime;
  const GalleryHistoryV2Data({
    required this.gid,
    required this.jsonBody,
    required this.lastReadTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gid'] = Variable<int>(gid);
    map['jsonBody'] = Variable<String>(jsonBody);
    map['lastReadTime'] = Variable<String>(lastReadTime);
    return map;
  }

  GalleryHistoryV2Companion toCompanion(bool nullToAbsent) {
    return GalleryHistoryV2Companion(
      gid: Value(gid),
      jsonBody: Value(jsonBody),
      lastReadTime: Value(lastReadTime),
    );
  }

  factory GalleryHistoryV2Data.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryHistoryV2Data(
      gid: serializer.fromJson<int>(json['gid']),
      jsonBody: serializer.fromJson<String>(json['jsonBody']),
      lastReadTime: serializer.fromJson<String>(json['lastReadTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gid': serializer.toJson<int>(gid),
      'jsonBody': serializer.toJson<String>(jsonBody),
      'lastReadTime': serializer.toJson<String>(lastReadTime),
    };
  }

  GalleryHistoryV2Data copyWith({
    int? gid,
    String? jsonBody,
    String? lastReadTime,
  }) => GalleryHistoryV2Data(
    gid: gid ?? this.gid,
    jsonBody: jsonBody ?? this.jsonBody,
    lastReadTime: lastReadTime ?? this.lastReadTime,
  );
  GalleryHistoryV2Data copyWithCompanion(GalleryHistoryV2Companion data) {
    return GalleryHistoryV2Data(
      gid: data.gid.present ? data.gid.value : this.gid,
      jsonBody: data.jsonBody.present ? data.jsonBody.value : this.jsonBody,
      lastReadTime: data.lastReadTime.present
          ? data.lastReadTime.value
          : this.lastReadTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GalleryHistoryV2Data(')
          ..write('gid: $gid, ')
          ..write('jsonBody: $jsonBody, ')
          ..write('lastReadTime: $lastReadTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(gid, jsonBody, lastReadTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryHistoryV2Data &&
          other.gid == this.gid &&
          other.jsonBody == this.jsonBody &&
          other.lastReadTime == this.lastReadTime);
}

class GalleryHistoryV2Companion extends UpdateCompanion<GalleryHistoryV2Data> {
  final Value<int> gid;
  final Value<String> jsonBody;
  final Value<String> lastReadTime;
  const GalleryHistoryV2Companion({
    this.gid = const Value.absent(),
    this.jsonBody = const Value.absent(),
    this.lastReadTime = const Value.absent(),
  });
  GalleryHistoryV2Companion.insert({
    this.gid = const Value.absent(),
    required String jsonBody,
    required String lastReadTime,
  }) : jsonBody = Value(jsonBody),
       lastReadTime = Value(lastReadTime);
  static Insertable<GalleryHistoryV2Data> custom({
    Expression<int>? gid,
    Expression<String>? jsonBody,
    Expression<String>? lastReadTime,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (jsonBody != null) 'jsonBody': jsonBody,
      if (lastReadTime != null) 'lastReadTime': lastReadTime,
    });
  }

  GalleryHistoryV2Companion copyWith({
    Value<int>? gid,
    Value<String>? jsonBody,
    Value<String>? lastReadTime,
  }) {
    return GalleryHistoryV2Companion(
      gid: gid ?? this.gid,
      jsonBody: jsonBody ?? this.jsonBody,
      lastReadTime: lastReadTime ?? this.lastReadTime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (jsonBody.present) {
      map['jsonBody'] = Variable<String>(jsonBody.value);
    }
    if (lastReadTime.present) {
      map['lastReadTime'] = Variable<String>(lastReadTime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryHistoryV2Companion(')
          ..write('gid: $gid, ')
          ..write('jsonBody: $jsonBody, ')
          ..write('lastReadTime: $lastReadTime')
          ..write(')'))
        .toString();
  }
}

class $TagCountTable extends TagCount
    with TableInfo<$TagCountTable, TagCountData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagCountTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _namespaceWithKeyMeta = const VerificationMeta(
    'namespaceWithKey',
  );
  @override
  late final GeneratedColumn<String> namespaceWithKey = GeneratedColumn<String>(
    'namespaceWithKey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [namespaceWithKey, count];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag_count';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagCountData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('namespaceWithKey')) {
      context.handle(
        _namespaceWithKeyMeta,
        namespaceWithKey.isAcceptableOrUnknown(
          data['namespaceWithKey']!,
          _namespaceWithKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_namespaceWithKeyMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {namespaceWithKey};
  @override
  TagCountData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagCountData(
      namespaceWithKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}namespaceWithKey'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
    );
  }

  @override
  $TagCountTable createAlias(String alias) {
    return $TagCountTable(attachedDatabase, alias);
  }
}

class TagCountData extends DataClass implements Insertable<TagCountData> {
  final String namespaceWithKey;
  final int count;
  const TagCountData({required this.namespaceWithKey, required this.count});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['namespaceWithKey'] = Variable<String>(namespaceWithKey);
    map['count'] = Variable<int>(count);
    return map;
  }

  TagCountCompanion toCompanion(bool nullToAbsent) {
    return TagCountCompanion(
      namespaceWithKey: Value(namespaceWithKey),
      count: Value(count),
    );
  }

  factory TagCountData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagCountData(
      namespaceWithKey: serializer.fromJson<String>(json['namespaceWithKey']),
      count: serializer.fromJson<int>(json['count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'namespaceWithKey': serializer.toJson<String>(namespaceWithKey),
      'count': serializer.toJson<int>(count),
    };
  }

  TagCountData copyWith({String? namespaceWithKey, int? count}) => TagCountData(
    namespaceWithKey: namespaceWithKey ?? this.namespaceWithKey,
    count: count ?? this.count,
  );
  TagCountData copyWithCompanion(TagCountCompanion data) {
    return TagCountData(
      namespaceWithKey: data.namespaceWithKey.present
          ? data.namespaceWithKey.value
          : this.namespaceWithKey,
      count: data.count.present ? data.count.value : this.count,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagCountData(')
          ..write('namespaceWithKey: $namespaceWithKey, ')
          ..write('count: $count')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(namespaceWithKey, count);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagCountData &&
          other.namespaceWithKey == this.namespaceWithKey &&
          other.count == this.count);
}

class TagCountCompanion extends UpdateCompanion<TagCountData> {
  final Value<String> namespaceWithKey;
  final Value<int> count;
  final Value<int> rowid;
  const TagCountCompanion({
    this.namespaceWithKey = const Value.absent(),
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagCountCompanion.insert({
    required String namespaceWithKey,
    required int count,
    this.rowid = const Value.absent(),
  }) : namespaceWithKey = Value(namespaceWithKey),
       count = Value(count);
  static Insertable<TagCountData> custom({
    Expression<String>? namespaceWithKey,
    Expression<int>? count,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (namespaceWithKey != null) 'namespaceWithKey': namespaceWithKey,
      if (count != null) 'count': count,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagCountCompanion copyWith({
    Value<String>? namespaceWithKey,
    Value<int>? count,
    Value<int>? rowid,
  }) {
    return TagCountCompanion(
      namespaceWithKey: namespaceWithKey ?? this.namespaceWithKey,
      count: count ?? this.count,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (namespaceWithKey.present) {
      map['namespaceWithKey'] = Variable<String>(namespaceWithKey.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagCountCompanion(')
          ..write('namespaceWithKey: $namespaceWithKey, ')
          ..write('count: $count, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DioCacheTable extends DioCache
    with TableInfo<$DioCacheTable, DioCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DioCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cacheKey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expireDateMeta = const VerificationMeta(
    'expireDate',
  );
  @override
  late final GeneratedColumn<DateTime> expireDate = GeneratedColumn<DateTime>(
    'expireDate',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<Uint8List> content = GeneratedColumn<Uint8List>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _headersMeta = const VerificationMeta(
    'headers',
  );
  @override
  late final GeneratedColumn<Uint8List> headers = GeneratedColumn<Uint8List>(
    'headers',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    url,
    expireDate,
    content,
    headers,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dio_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<DioCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cacheKey')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cacheKey']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('expireDate')) {
      context.handle(
        _expireDateMeta,
        expireDate.isAcceptableOrUnknown(data['expireDate']!, _expireDateMeta),
      );
    } else if (isInserting) {
      context.missing(_expireDateMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('headers')) {
      context.handle(
        _headersMeta,
        headers.isAcceptableOrUnknown(data['headers']!, _headersMeta),
      );
    } else if (isInserting) {
      context.missing(_headersMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  DioCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DioCacheData(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cacheKey'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      expireDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expireDate'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}content'],
      )!,
      headers: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}headers'],
      )!,
    );
  }

  @override
  $DioCacheTable createAlias(String alias) {
    return $DioCacheTable(attachedDatabase, alias);
  }
}

class DioCacheData extends DataClass implements Insertable<DioCacheData> {
  final String cacheKey;
  final String url;
  final DateTime expireDate;
  final Uint8List content;
  final Uint8List headers;
  const DioCacheData({
    required this.cacheKey,
    required this.url,
    required this.expireDate,
    required this.content,
    required this.headers,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cacheKey'] = Variable<String>(cacheKey);
    map['url'] = Variable<String>(url);
    map['expireDate'] = Variable<DateTime>(expireDate);
    map['content'] = Variable<Uint8List>(content);
    map['headers'] = Variable<Uint8List>(headers);
    return map;
  }

  DioCacheCompanion toCompanion(bool nullToAbsent) {
    return DioCacheCompanion(
      cacheKey: Value(cacheKey),
      url: Value(url),
      expireDate: Value(expireDate),
      content: Value(content),
      headers: Value(headers),
    );
  }

  factory DioCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DioCacheData(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      url: serializer.fromJson<String>(json['url']),
      expireDate: serializer.fromJson<DateTime>(json['expireDate']),
      content: serializer.fromJson<Uint8List>(json['content']),
      headers: serializer.fromJson<Uint8List>(json['headers']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'url': serializer.toJson<String>(url),
      'expireDate': serializer.toJson<DateTime>(expireDate),
      'content': serializer.toJson<Uint8List>(content),
      'headers': serializer.toJson<Uint8List>(headers),
    };
  }

  DioCacheData copyWith({
    String? cacheKey,
    String? url,
    DateTime? expireDate,
    Uint8List? content,
    Uint8List? headers,
  }) => DioCacheData(
    cacheKey: cacheKey ?? this.cacheKey,
    url: url ?? this.url,
    expireDate: expireDate ?? this.expireDate,
    content: content ?? this.content,
    headers: headers ?? this.headers,
  );
  DioCacheData copyWithCompanion(DioCacheCompanion data) {
    return DioCacheData(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      url: data.url.present ? data.url.value : this.url,
      expireDate: data.expireDate.present
          ? data.expireDate.value
          : this.expireDate,
      content: data.content.present ? data.content.value : this.content,
      headers: data.headers.present ? data.headers.value : this.headers,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DioCacheData(')
          ..write('cacheKey: $cacheKey, ')
          ..write('url: $url, ')
          ..write('expireDate: $expireDate, ')
          ..write('content: $content, ')
          ..write('headers: $headers')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cacheKey,
    url,
    expireDate,
    $driftBlobEquality.hash(content),
    $driftBlobEquality.hash(headers),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DioCacheData &&
          other.cacheKey == this.cacheKey &&
          other.url == this.url &&
          other.expireDate == this.expireDate &&
          $driftBlobEquality.equals(other.content, this.content) &&
          $driftBlobEquality.equals(other.headers, this.headers));
}

class DioCacheCompanion extends UpdateCompanion<DioCacheData> {
  final Value<String> cacheKey;
  final Value<String> url;
  final Value<DateTime> expireDate;
  final Value<Uint8List> content;
  final Value<Uint8List> headers;
  final Value<int> rowid;
  const DioCacheCompanion({
    this.cacheKey = const Value.absent(),
    this.url = const Value.absent(),
    this.expireDate = const Value.absent(),
    this.content = const Value.absent(),
    this.headers = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DioCacheCompanion.insert({
    required String cacheKey,
    required String url,
    required DateTime expireDate,
    required Uint8List content,
    required Uint8List headers,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       url = Value(url),
       expireDate = Value(expireDate),
       content = Value(content),
       headers = Value(headers);
  static Insertable<DioCacheData> custom({
    Expression<String>? cacheKey,
    Expression<String>? url,
    Expression<DateTime>? expireDate,
    Expression<Uint8List>? content,
    Expression<Uint8List>? headers,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cacheKey': cacheKey,
      if (url != null) 'url': url,
      if (expireDate != null) 'expireDate': expireDate,
      if (content != null) 'content': content,
      if (headers != null) 'headers': headers,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DioCacheCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? url,
    Value<DateTime>? expireDate,
    Value<Uint8List>? content,
    Value<Uint8List>? headers,
    Value<int>? rowid,
  }) {
    return DioCacheCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      url: url ?? this.url,
      expireDate: expireDate ?? this.expireDate,
      content: content ?? this.content,
      headers: headers ?? this.headers,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cacheKey'] = Variable<String>(cacheKey.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (expireDate.present) {
      map['expireDate'] = Variable<DateTime>(expireDate.value);
    }
    if (content.present) {
      map['content'] = Variable<Uint8List>(content.value);
    }
    if (headers.present) {
      map['headers'] = Variable<Uint8List>(headers.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DioCacheCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('url: $url, ')
          ..write('expireDate: $expireDate, ')
          ..write('content: $content, ')
          ..write('headers: $headers, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlockRuleTable extends BlockRule
    with TableInfo<$BlockRuleTable, BlockRuleData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlockRuleTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<int> target = GeneratedColumn<int>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attributeMeta = const VerificationMeta(
    'attribute',
  );
  @override
  late final GeneratedColumn<int> attribute = GeneratedColumn<int>(
    'attribute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patternMeta = const VerificationMeta(
    'pattern',
  );
  @override
  late final GeneratedColumn<int> pattern = GeneratedColumn<int>(
    'pattern',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expressionMeta = const VerificationMeta(
    'expression',
  );
  @override
  late final GeneratedColumn<String> expression = GeneratedColumn<String>(
    'expression',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    target,
    attribute,
    pattern,
    expression,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'block_rule';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlockRuleData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('target')) {
      context.handle(
        _targetMeta,
        target.isAcceptableOrUnknown(data['target']!, _targetMeta),
      );
    } else if (isInserting) {
      context.missing(_targetMeta);
    }
    if (data.containsKey('attribute')) {
      context.handle(
        _attributeMeta,
        attribute.isAcceptableOrUnknown(data['attribute']!, _attributeMeta),
      );
    } else if (isInserting) {
      context.missing(_attributeMeta);
    }
    if (data.containsKey('pattern')) {
      context.handle(
        _patternMeta,
        pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta),
      );
    } else if (isInserting) {
      context.missing(_patternMeta);
    }
    if (data.containsKey('expression')) {
      context.handle(
        _expressionMeta,
        expression.isAcceptableOrUnknown(data['expression']!, _expressionMeta),
      );
    } else if (isInserting) {
      context.missing(_expressionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BlockRuleData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlockRuleData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target'],
      )!,
      attribute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attribute'],
      )!,
      pattern: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pattern'],
      )!,
      expression: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expression'],
      )!,
    );
  }

  @override
  $BlockRuleTable createAlias(String alias) {
    return $BlockRuleTable(attachedDatabase, alias);
  }
}

class BlockRuleData extends DataClass implements Insertable<BlockRuleData> {
  final int id;
  final String groupId;
  final int target;
  final int attribute;
  final int pattern;
  final String expression;
  const BlockRuleData({
    required this.id,
    required this.groupId,
    required this.target,
    required this.attribute,
    required this.pattern,
    required this.expression,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['group_id'] = Variable<String>(groupId);
    map['target'] = Variable<int>(target);
    map['attribute'] = Variable<int>(attribute);
    map['pattern'] = Variable<int>(pattern);
    map['expression'] = Variable<String>(expression);
    return map;
  }

  BlockRuleCompanion toCompanion(bool nullToAbsent) {
    return BlockRuleCompanion(
      id: Value(id),
      groupId: Value(groupId),
      target: Value(target),
      attribute: Value(attribute),
      pattern: Value(pattern),
      expression: Value(expression),
    );
  }

  factory BlockRuleData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlockRuleData(
      id: serializer.fromJson<int>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      target: serializer.fromJson<int>(json['target']),
      attribute: serializer.fromJson<int>(json['attribute']),
      pattern: serializer.fromJson<int>(json['pattern']),
      expression: serializer.fromJson<String>(json['expression']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'groupId': serializer.toJson<String>(groupId),
      'target': serializer.toJson<int>(target),
      'attribute': serializer.toJson<int>(attribute),
      'pattern': serializer.toJson<int>(pattern),
      'expression': serializer.toJson<String>(expression),
    };
  }

  BlockRuleData copyWith({
    int? id,
    String? groupId,
    int? target,
    int? attribute,
    int? pattern,
    String? expression,
  }) => BlockRuleData(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    target: target ?? this.target,
    attribute: attribute ?? this.attribute,
    pattern: pattern ?? this.pattern,
    expression: expression ?? this.expression,
  );
  BlockRuleData copyWithCompanion(BlockRuleCompanion data) {
    return BlockRuleData(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      target: data.target.present ? data.target.value : this.target,
      attribute: data.attribute.present ? data.attribute.value : this.attribute,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      expression: data.expression.present
          ? data.expression.value
          : this.expression,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlockRuleData(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('target: $target, ')
          ..write('attribute: $attribute, ')
          ..write('pattern: $pattern, ')
          ..write('expression: $expression')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, groupId, target, attribute, pattern, expression);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlockRuleData &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.target == this.target &&
          other.attribute == this.attribute &&
          other.pattern == this.pattern &&
          other.expression == this.expression);
}

class BlockRuleCompanion extends UpdateCompanion<BlockRuleData> {
  final Value<int> id;
  final Value<String> groupId;
  final Value<int> target;
  final Value<int> attribute;
  final Value<int> pattern;
  final Value<String> expression;
  const BlockRuleCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.target = const Value.absent(),
    this.attribute = const Value.absent(),
    this.pattern = const Value.absent(),
    this.expression = const Value.absent(),
  });
  BlockRuleCompanion.insert({
    this.id = const Value.absent(),
    required String groupId,
    required int target,
    required int attribute,
    required int pattern,
    required String expression,
  }) : groupId = Value(groupId),
       target = Value(target),
       attribute = Value(attribute),
       pattern = Value(pattern),
       expression = Value(expression);
  static Insertable<BlockRuleData> custom({
    Expression<int>? id,
    Expression<String>? groupId,
    Expression<int>? target,
    Expression<int>? attribute,
    Expression<int>? pattern,
    Expression<String>? expression,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (target != null) 'target': target,
      if (attribute != null) 'attribute': attribute,
      if (pattern != null) 'pattern': pattern,
      if (expression != null) 'expression': expression,
    });
  }

  BlockRuleCompanion copyWith({
    Value<int>? id,
    Value<String>? groupId,
    Value<int>? target,
    Value<int>? attribute,
    Value<int>? pattern,
    Value<String>? expression,
  }) {
    return BlockRuleCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      target: target ?? this.target,
      attribute: attribute ?? this.attribute,
      pattern: pattern ?? this.pattern,
      expression: expression ?? this.expression,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (target.present) {
      map['target'] = Variable<int>(target.value);
    }
    if (attribute.present) {
      map['attribute'] = Variable<int>(attribute.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<int>(pattern.value);
    }
    if (expression.present) {
      map['expression'] = Variable<String>(expression.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlockRuleCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('target: $target, ')
          ..write('attribute: $attribute, ')
          ..write('pattern: $pattern, ')
          ..write('expression: $expression')
          ..write(')'))
        .toString();
  }
}

class $LocalConfigTable extends LocalConfig
    with TableInfo<$LocalConfigTable, LocalConfigData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalConfigTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _configKeyMeta = const VerificationMeta(
    'configKey',
  );
  @override
  late final GeneratedColumn<String> configKey = GeneratedColumn<String>(
    'config_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subConfigKeyMeta = const VerificationMeta(
    'subConfigKey',
  );
  @override
  late final GeneratedColumn<String> subConfigKey = GeneratedColumn<String>(
    'sub_config_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _utimeMeta = const VerificationMeta('utime');
  @override
  late final GeneratedColumn<String> utime = GeneratedColumn<String>(
    'utime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [configKey, subConfigKey, value, utime];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_config';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalConfigData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('config_key')) {
      context.handle(
        _configKeyMeta,
        configKey.isAcceptableOrUnknown(data['config_key']!, _configKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_configKeyMeta);
    }
    if (data.containsKey('sub_config_key')) {
      context.handle(
        _subConfigKeyMeta,
        subConfigKey.isAcceptableOrUnknown(
          data['sub_config_key']!,
          _subConfigKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subConfigKeyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('utime')) {
      context.handle(
        _utimeMeta,
        utime.isAcceptableOrUnknown(data['utime']!, _utimeMeta),
      );
    } else if (isInserting) {
      context.missing(_utimeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {configKey, subConfigKey};
  @override
  LocalConfigData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalConfigData(
      configKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_key'],
      )!,
      subConfigKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_config_key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      utime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}utime'],
      )!,
    );
  }

  @override
  $LocalConfigTable createAlias(String alias) {
    return $LocalConfigTable(attachedDatabase, alias);
  }
}

class LocalConfigData extends DataClass implements Insertable<LocalConfigData> {
  final String configKey;
  final String subConfigKey;
  final String value;
  final String utime;
  const LocalConfigData({
    required this.configKey,
    required this.subConfigKey,
    required this.value,
    required this.utime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['config_key'] = Variable<String>(configKey);
    map['sub_config_key'] = Variable<String>(subConfigKey);
    map['value'] = Variable<String>(value);
    map['utime'] = Variable<String>(utime);
    return map;
  }

  LocalConfigCompanion toCompanion(bool nullToAbsent) {
    return LocalConfigCompanion(
      configKey: Value(configKey),
      subConfigKey: Value(subConfigKey),
      value: Value(value),
      utime: Value(utime),
    );
  }

  factory LocalConfigData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalConfigData(
      configKey: serializer.fromJson<String>(json['configKey']),
      subConfigKey: serializer.fromJson<String>(json['subConfigKey']),
      value: serializer.fromJson<String>(json['value']),
      utime: serializer.fromJson<String>(json['utime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'configKey': serializer.toJson<String>(configKey),
      'subConfigKey': serializer.toJson<String>(subConfigKey),
      'value': serializer.toJson<String>(value),
      'utime': serializer.toJson<String>(utime),
    };
  }

  LocalConfigData copyWith({
    String? configKey,
    String? subConfigKey,
    String? value,
    String? utime,
  }) => LocalConfigData(
    configKey: configKey ?? this.configKey,
    subConfigKey: subConfigKey ?? this.subConfigKey,
    value: value ?? this.value,
    utime: utime ?? this.utime,
  );
  LocalConfigData copyWithCompanion(LocalConfigCompanion data) {
    return LocalConfigData(
      configKey: data.configKey.present ? data.configKey.value : this.configKey,
      subConfigKey: data.subConfigKey.present
          ? data.subConfigKey.value
          : this.subConfigKey,
      value: data.value.present ? data.value.value : this.value,
      utime: data.utime.present ? data.utime.value : this.utime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalConfigData(')
          ..write('configKey: $configKey, ')
          ..write('subConfigKey: $subConfigKey, ')
          ..write('value: $value, ')
          ..write('utime: $utime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(configKey, subConfigKey, value, utime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalConfigData &&
          other.configKey == this.configKey &&
          other.subConfigKey == this.subConfigKey &&
          other.value == this.value &&
          other.utime == this.utime);
}

class LocalConfigCompanion extends UpdateCompanion<LocalConfigData> {
  final Value<String> configKey;
  final Value<String> subConfigKey;
  final Value<String> value;
  final Value<String> utime;
  final Value<int> rowid;
  const LocalConfigCompanion({
    this.configKey = const Value.absent(),
    this.subConfigKey = const Value.absent(),
    this.value = const Value.absent(),
    this.utime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalConfigCompanion.insert({
    required String configKey,
    required String subConfigKey,
    required String value,
    required String utime,
    this.rowid = const Value.absent(),
  }) : configKey = Value(configKey),
       subConfigKey = Value(subConfigKey),
       value = Value(value),
       utime = Value(utime);
  static Insertable<LocalConfigData> custom({
    Expression<String>? configKey,
    Expression<String>? subConfigKey,
    Expression<String>? value,
    Expression<String>? utime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (configKey != null) 'config_key': configKey,
      if (subConfigKey != null) 'sub_config_key': subConfigKey,
      if (value != null) 'value': value,
      if (utime != null) 'utime': utime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalConfigCompanion copyWith({
    Value<String>? configKey,
    Value<String>? subConfigKey,
    Value<String>? value,
    Value<String>? utime,
    Value<int>? rowid,
  }) {
    return LocalConfigCompanion(
      configKey: configKey ?? this.configKey,
      subConfigKey: subConfigKey ?? this.subConfigKey,
      value: value ?? this.value,
      utime: utime ?? this.utime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (configKey.present) {
      map['config_key'] = Variable<String>(configKey.value);
    }
    if (subConfigKey.present) {
      map['sub_config_key'] = Variable<String>(subConfigKey.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (utime.present) {
      map['utime'] = Variable<String>(utime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalConfigCompanion(')
          ..write('configKey: $configKey, ')
          ..write('subConfigKey: $subConfigKey, ')
          ..write('value: $value, ')
          ..write('utime: $utime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentPageTable extends ContentPage
    with TableInfo<$ContentPageTable, ContentPageData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentPageTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _copyIdMeta = const VerificationMeta('copyId');
  @override
  late final GeneratedColumn<String> copyId = GeneratedColumn<String>(
    'copy_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawHashMeta = const VerificationMeta(
    'rawHash',
  );
  @override
  late final GeneratedColumn<String> rawHash = GeneratedColumn<String>(
    'raw_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawLengthMeta = const VerificationMeta(
    'rawLength',
  );
  @override
  late final GeneratedColumn<int> rawLength = GeneratedColumn<int>(
    'raw_length',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codecProfileMeta = const VerificationMeta(
    'codecProfile',
  );
  @override
  late final GeneratedColumn<String> codecProfile = GeneratedColumn<String>(
    'codec_profile',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _objectHashMeta = const VerificationMeta(
    'objectHash',
  );
  @override
  late final GeneratedColumn<String> objectHash = GeneratedColumn<String>(
    'object_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _storedLengthMeta = const VerificationMeta(
    'storedLength',
  );
  @override
  late final GeneratedColumn<int> storedLength = GeneratedColumn<int>(
    'stored_length',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourcePageUrlMeta = const VerificationMeta(
    'sourcePageUrl',
  );
  @override
  late final GeneratedColumn<String> sourcePageUrl = GeneratedColumn<String>(
    'source_page_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    copyId,
    ordinal,
    relativePath,
    rawHash,
    rawLength,
    codecProfile,
    objectHash,
    storedLength,
    mime,
    width,
    height,
    sourcePageUrl,
    state,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_page';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentPageData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('copy_id')) {
      context.handle(
        _copyIdMeta,
        copyId.isAcceptableOrUnknown(data['copy_id']!, _copyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_copyIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('raw_hash')) {
      context.handle(
        _rawHashMeta,
        rawHash.isAcceptableOrUnknown(data['raw_hash']!, _rawHashMeta),
      );
    }
    if (data.containsKey('raw_length')) {
      context.handle(
        _rawLengthMeta,
        rawLength.isAcceptableOrUnknown(data['raw_length']!, _rawLengthMeta),
      );
    }
    if (data.containsKey('codec_profile')) {
      context.handle(
        _codecProfileMeta,
        codecProfile.isAcceptableOrUnknown(
          data['codec_profile']!,
          _codecProfileMeta,
        ),
      );
    }
    if (data.containsKey('object_hash')) {
      context.handle(
        _objectHashMeta,
        objectHash.isAcceptableOrUnknown(data['object_hash']!, _objectHashMeta),
      );
    }
    if (data.containsKey('stored_length')) {
      context.handle(
        _storedLengthMeta,
        storedLength.isAcceptableOrUnknown(
          data['stored_length']!,
          _storedLengthMeta,
        ),
      );
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('source_page_url')) {
      context.handle(
        _sourcePageUrlMeta,
        sourcePageUrl.isAcceptableOrUnknown(
          data['source_page_url']!,
          _sourcePageUrlMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {copyId, ordinal};
  @override
  ContentPageData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentPageData(
      copyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}copy_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      rawHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_hash'],
      ),
      rawLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}raw_length'],
      ),
      codecProfile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}codec_profile'],
      ),
      objectHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}object_hash'],
      ),
      storedLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stored_length'],
      ),
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      sourcePageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_page_url'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
    );
  }

  @override
  $ContentPageTable createAlias(String alias) {
    return $ContentPageTable(attachedDatabase, alias);
  }
}

class ContentPageData extends DataClass implements Insertable<ContentPageData> {
  final String copyId;
  final int ordinal;
  final String relativePath;
  final String? rawHash;
  final int? rawLength;
  final String? codecProfile;
  final String? objectHash;
  final int? storedLength;
  final String? mime;
  final int? width;
  final int? height;
  final String? sourcePageUrl;
  final String state;
  const ContentPageData({
    required this.copyId,
    required this.ordinal,
    required this.relativePath,
    this.rawHash,
    this.rawLength,
    this.codecProfile,
    this.objectHash,
    this.storedLength,
    this.mime,
    this.width,
    this.height,
    this.sourcePageUrl,
    required this.state,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['copy_id'] = Variable<String>(copyId);
    map['ordinal'] = Variable<int>(ordinal);
    map['relative_path'] = Variable<String>(relativePath);
    if (!nullToAbsent || rawHash != null) {
      map['raw_hash'] = Variable<String>(rawHash);
    }
    if (!nullToAbsent || rawLength != null) {
      map['raw_length'] = Variable<int>(rawLength);
    }
    if (!nullToAbsent || codecProfile != null) {
      map['codec_profile'] = Variable<String>(codecProfile);
    }
    if (!nullToAbsent || objectHash != null) {
      map['object_hash'] = Variable<String>(objectHash);
    }
    if (!nullToAbsent || storedLength != null) {
      map['stored_length'] = Variable<int>(storedLength);
    }
    if (!nullToAbsent || mime != null) {
      map['mime'] = Variable<String>(mime);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || sourcePageUrl != null) {
      map['source_page_url'] = Variable<String>(sourcePageUrl);
    }
    map['state'] = Variable<String>(state);
    return map;
  }

  ContentPageCompanion toCompanion(bool nullToAbsent) {
    return ContentPageCompanion(
      copyId: Value(copyId),
      ordinal: Value(ordinal),
      relativePath: Value(relativePath),
      rawHash: rawHash == null && nullToAbsent
          ? const Value.absent()
          : Value(rawHash),
      rawLength: rawLength == null && nullToAbsent
          ? const Value.absent()
          : Value(rawLength),
      codecProfile: codecProfile == null && nullToAbsent
          ? const Value.absent()
          : Value(codecProfile),
      objectHash: objectHash == null && nullToAbsent
          ? const Value.absent()
          : Value(objectHash),
      storedLength: storedLength == null && nullToAbsent
          ? const Value.absent()
          : Value(storedLength),
      mime: mime == null && nullToAbsent ? const Value.absent() : Value(mime),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      sourcePageUrl: sourcePageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourcePageUrl),
      state: Value(state),
    );
  }

  factory ContentPageData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentPageData(
      copyId: serializer.fromJson<String>(json['copyId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      rawHash: serializer.fromJson<String?>(json['rawHash']),
      rawLength: serializer.fromJson<int?>(json['rawLength']),
      codecProfile: serializer.fromJson<String?>(json['codecProfile']),
      objectHash: serializer.fromJson<String?>(json['objectHash']),
      storedLength: serializer.fromJson<int?>(json['storedLength']),
      mime: serializer.fromJson<String?>(json['mime']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      sourcePageUrl: serializer.fromJson<String?>(json['sourcePageUrl']),
      state: serializer.fromJson<String>(json['state']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'copyId': serializer.toJson<String>(copyId),
      'ordinal': serializer.toJson<int>(ordinal),
      'relativePath': serializer.toJson<String>(relativePath),
      'rawHash': serializer.toJson<String?>(rawHash),
      'rawLength': serializer.toJson<int?>(rawLength),
      'codecProfile': serializer.toJson<String?>(codecProfile),
      'objectHash': serializer.toJson<String?>(objectHash),
      'storedLength': serializer.toJson<int?>(storedLength),
      'mime': serializer.toJson<String?>(mime),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'sourcePageUrl': serializer.toJson<String?>(sourcePageUrl),
      'state': serializer.toJson<String>(state),
    };
  }

  ContentPageData copyWith({
    String? copyId,
    int? ordinal,
    String? relativePath,
    Value<String?> rawHash = const Value.absent(),
    Value<int?> rawLength = const Value.absent(),
    Value<String?> codecProfile = const Value.absent(),
    Value<String?> objectHash = const Value.absent(),
    Value<int?> storedLength = const Value.absent(),
    Value<String?> mime = const Value.absent(),
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<String?> sourcePageUrl = const Value.absent(),
    String? state,
  }) => ContentPageData(
    copyId: copyId ?? this.copyId,
    ordinal: ordinal ?? this.ordinal,
    relativePath: relativePath ?? this.relativePath,
    rawHash: rawHash.present ? rawHash.value : this.rawHash,
    rawLength: rawLength.present ? rawLength.value : this.rawLength,
    codecProfile: codecProfile.present ? codecProfile.value : this.codecProfile,
    objectHash: objectHash.present ? objectHash.value : this.objectHash,
    storedLength: storedLength.present ? storedLength.value : this.storedLength,
    mime: mime.present ? mime.value : this.mime,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    sourcePageUrl: sourcePageUrl.present
        ? sourcePageUrl.value
        : this.sourcePageUrl,
    state: state ?? this.state,
  );
  ContentPageData copyWithCompanion(ContentPageCompanion data) {
    return ContentPageData(
      copyId: data.copyId.present ? data.copyId.value : this.copyId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      rawHash: data.rawHash.present ? data.rawHash.value : this.rawHash,
      rawLength: data.rawLength.present ? data.rawLength.value : this.rawLength,
      codecProfile: data.codecProfile.present
          ? data.codecProfile.value
          : this.codecProfile,
      objectHash: data.objectHash.present
          ? data.objectHash.value
          : this.objectHash,
      storedLength: data.storedLength.present
          ? data.storedLength.value
          : this.storedLength,
      mime: data.mime.present ? data.mime.value : this.mime,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      sourcePageUrl: data.sourcePageUrl.present
          ? data.sourcePageUrl.value
          : this.sourcePageUrl,
      state: data.state.present ? data.state.value : this.state,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentPageData(')
          ..write('copyId: $copyId, ')
          ..write('ordinal: $ordinal, ')
          ..write('relativePath: $relativePath, ')
          ..write('rawHash: $rawHash, ')
          ..write('rawLength: $rawLength, ')
          ..write('codecProfile: $codecProfile, ')
          ..write('objectHash: $objectHash, ')
          ..write('storedLength: $storedLength, ')
          ..write('mime: $mime, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sourcePageUrl: $sourcePageUrl, ')
          ..write('state: $state')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    copyId,
    ordinal,
    relativePath,
    rawHash,
    rawLength,
    codecProfile,
    objectHash,
    storedLength,
    mime,
    width,
    height,
    sourcePageUrl,
    state,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentPageData &&
          other.copyId == this.copyId &&
          other.ordinal == this.ordinal &&
          other.relativePath == this.relativePath &&
          other.rawHash == this.rawHash &&
          other.rawLength == this.rawLength &&
          other.codecProfile == this.codecProfile &&
          other.objectHash == this.objectHash &&
          other.storedLength == this.storedLength &&
          other.mime == this.mime &&
          other.width == this.width &&
          other.height == this.height &&
          other.sourcePageUrl == this.sourcePageUrl &&
          other.state == this.state);
}

class ContentPageCompanion extends UpdateCompanion<ContentPageData> {
  final Value<String> copyId;
  final Value<int> ordinal;
  final Value<String> relativePath;
  final Value<String?> rawHash;
  final Value<int?> rawLength;
  final Value<String?> codecProfile;
  final Value<String?> objectHash;
  final Value<int?> storedLength;
  final Value<String?> mime;
  final Value<int?> width;
  final Value<int?> height;
  final Value<String?> sourcePageUrl;
  final Value<String> state;
  final Value<int> rowid;
  const ContentPageCompanion({
    this.copyId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.rawHash = const Value.absent(),
    this.rawLength = const Value.absent(),
    this.codecProfile = const Value.absent(),
    this.objectHash = const Value.absent(),
    this.storedLength = const Value.absent(),
    this.mime = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sourcePageUrl = const Value.absent(),
    this.state = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentPageCompanion.insert({
    required String copyId,
    required int ordinal,
    required String relativePath,
    this.rawHash = const Value.absent(),
    this.rawLength = const Value.absent(),
    this.codecProfile = const Value.absent(),
    this.objectHash = const Value.absent(),
    this.storedLength = const Value.absent(),
    this.mime = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sourcePageUrl = const Value.absent(),
    required String state,
    this.rowid = const Value.absent(),
  }) : copyId = Value(copyId),
       ordinal = Value(ordinal),
       relativePath = Value(relativePath),
       state = Value(state);
  static Insertable<ContentPageData> custom({
    Expression<String>? copyId,
    Expression<int>? ordinal,
    Expression<String>? relativePath,
    Expression<String>? rawHash,
    Expression<int>? rawLength,
    Expression<String>? codecProfile,
    Expression<String>? objectHash,
    Expression<int>? storedLength,
    Expression<String>? mime,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? sourcePageUrl,
    Expression<String>? state,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (copyId != null) 'copy_id': copyId,
      if (ordinal != null) 'ordinal': ordinal,
      if (relativePath != null) 'relative_path': relativePath,
      if (rawHash != null) 'raw_hash': rawHash,
      if (rawLength != null) 'raw_length': rawLength,
      if (codecProfile != null) 'codec_profile': codecProfile,
      if (objectHash != null) 'object_hash': objectHash,
      if (storedLength != null) 'stored_length': storedLength,
      if (mime != null) 'mime': mime,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (sourcePageUrl != null) 'source_page_url': sourcePageUrl,
      if (state != null) 'state': state,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentPageCompanion copyWith({
    Value<String>? copyId,
    Value<int>? ordinal,
    Value<String>? relativePath,
    Value<String?>? rawHash,
    Value<int?>? rawLength,
    Value<String?>? codecProfile,
    Value<String?>? objectHash,
    Value<int?>? storedLength,
    Value<String?>? mime,
    Value<int?>? width,
    Value<int?>? height,
    Value<String?>? sourcePageUrl,
    Value<String>? state,
    Value<int>? rowid,
  }) {
    return ContentPageCompanion(
      copyId: copyId ?? this.copyId,
      ordinal: ordinal ?? this.ordinal,
      relativePath: relativePath ?? this.relativePath,
      rawHash: rawHash ?? this.rawHash,
      rawLength: rawLength ?? this.rawLength,
      codecProfile: codecProfile ?? this.codecProfile,
      objectHash: objectHash ?? this.objectHash,
      storedLength: storedLength ?? this.storedLength,
      mime: mime ?? this.mime,
      width: width ?? this.width,
      height: height ?? this.height,
      sourcePageUrl: sourcePageUrl ?? this.sourcePageUrl,
      state: state ?? this.state,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (copyId.present) {
      map['copy_id'] = Variable<String>(copyId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (rawHash.present) {
      map['raw_hash'] = Variable<String>(rawHash.value);
    }
    if (rawLength.present) {
      map['raw_length'] = Variable<int>(rawLength.value);
    }
    if (codecProfile.present) {
      map['codec_profile'] = Variable<String>(codecProfile.value);
    }
    if (objectHash.present) {
      map['object_hash'] = Variable<String>(objectHash.value);
    }
    if (storedLength.present) {
      map['stored_length'] = Variable<int>(storedLength.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (sourcePageUrl.present) {
      map['source_page_url'] = Variable<String>(sourcePageUrl.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentPageCompanion(')
          ..write('copyId: $copyId, ')
          ..write('ordinal: $ordinal, ')
          ..write('relativePath: $relativePath, ')
          ..write('rawHash: $rawHash, ')
          ..write('rawLength: $rawLength, ')
          ..write('codecProfile: $codecProfile, ')
          ..write('objectHash: $objectHash, ')
          ..write('storedLength: $storedLength, ')
          ..write('mime: $mime, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sourcePageUrl: $sourcePageUrl, ')
          ..write('state: $state, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentRemoteResourceTable extends ContentRemoteResource
    with TableInfo<$ContentRemoteResourceTable, ContentRemoteResourceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentRemoteResourceTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _targetNamespaceMeta = const VerificationMeta(
    'targetNamespace',
  );
  @override
  late final GeneratedColumn<String> targetNamespace = GeneratedColumn<String>(
    'target_namespace',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hrefMeta = const VerificationMeta('href');
  @override
  late final GeneratedColumn<String> href = GeneratedColumn<String>(
    'href',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _objectHashMeta = const VerificationMeta(
    'objectHash',
  );
  @override
  late final GeneratedColumn<String> objectHash = GeneratedColumn<String>(
    'object_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partitionMeta = const VerificationMeta(
    'partition',
  );
  @override
  late final GeneratedColumn<String> partition = GeneratedColumn<String>(
    'partition',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _observedAtMeta = const VerificationMeta(
    'observedAt',
  );
  @override
  late final GeneratedColumn<String> observedAt = GeneratedColumn<String>(
    'observed_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    targetNamespace,
    href,
    kind,
    objectHash,
    etag,
    partition,
    observedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_remote_resource';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentRemoteResourceData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('target_namespace')) {
      context.handle(
        _targetNamespaceMeta,
        targetNamespace.isAcceptableOrUnknown(
          data['target_namespace']!,
          _targetNamespaceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetNamespaceMeta);
    }
    if (data.containsKey('href')) {
      context.handle(
        _hrefMeta,
        href.isAcceptableOrUnknown(data['href']!, _hrefMeta),
      );
    } else if (isInserting) {
      context.missing(_hrefMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('object_hash')) {
      context.handle(
        _objectHashMeta,
        objectHash.isAcceptableOrUnknown(data['object_hash']!, _objectHashMeta),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('partition')) {
      context.handle(
        _partitionMeta,
        partition.isAcceptableOrUnknown(data['partition']!, _partitionMeta),
      );
    }
    if (data.containsKey('observed_at')) {
      context.handle(
        _observedAtMeta,
        observedAt.isAcceptableOrUnknown(data['observed_at']!, _observedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_observedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {targetNamespace, href};
  @override
  ContentRemoteResourceData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentRemoteResourceData(
      targetNamespace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_namespace'],
      )!,
      href: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}href'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      objectHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}object_hash'],
      ),
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      partition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}partition'],
      ),
      observedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}observed_at'],
      )!,
    );
  }

  @override
  $ContentRemoteResourceTable createAlias(String alias) {
    return $ContentRemoteResourceTable(attachedDatabase, alias);
  }
}

class ContentRemoteResourceData extends DataClass
    implements Insertable<ContentRemoteResourceData> {
  final String targetNamespace;
  final String href;
  final String kind;
  final String? objectHash;
  final String? etag;
  final String? partition;
  final String observedAt;
  const ContentRemoteResourceData({
    required this.targetNamespace,
    required this.href,
    required this.kind,
    this.objectHash,
    this.etag,
    this.partition,
    required this.observedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['target_namespace'] = Variable<String>(targetNamespace);
    map['href'] = Variable<String>(href);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || objectHash != null) {
      map['object_hash'] = Variable<String>(objectHash);
    }
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || partition != null) {
      map['partition'] = Variable<String>(partition);
    }
    map['observed_at'] = Variable<String>(observedAt);
    return map;
  }

  ContentRemoteResourceCompanion toCompanion(bool nullToAbsent) {
    return ContentRemoteResourceCompanion(
      targetNamespace: Value(targetNamespace),
      href: Value(href),
      kind: Value(kind),
      objectHash: objectHash == null && nullToAbsent
          ? const Value.absent()
          : Value(objectHash),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      partition: partition == null && nullToAbsent
          ? const Value.absent()
          : Value(partition),
      observedAt: Value(observedAt),
    );
  }

  factory ContentRemoteResourceData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentRemoteResourceData(
      targetNamespace: serializer.fromJson<String>(json['targetNamespace']),
      href: serializer.fromJson<String>(json['href']),
      kind: serializer.fromJson<String>(json['kind']),
      objectHash: serializer.fromJson<String?>(json['objectHash']),
      etag: serializer.fromJson<String?>(json['etag']),
      partition: serializer.fromJson<String?>(json['partition']),
      observedAt: serializer.fromJson<String>(json['observedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'targetNamespace': serializer.toJson<String>(targetNamespace),
      'href': serializer.toJson<String>(href),
      'kind': serializer.toJson<String>(kind),
      'objectHash': serializer.toJson<String?>(objectHash),
      'etag': serializer.toJson<String?>(etag),
      'partition': serializer.toJson<String?>(partition),
      'observedAt': serializer.toJson<String>(observedAt),
    };
  }

  ContentRemoteResourceData copyWith({
    String? targetNamespace,
    String? href,
    String? kind,
    Value<String?> objectHash = const Value.absent(),
    Value<String?> etag = const Value.absent(),
    Value<String?> partition = const Value.absent(),
    String? observedAt,
  }) => ContentRemoteResourceData(
    targetNamespace: targetNamespace ?? this.targetNamespace,
    href: href ?? this.href,
    kind: kind ?? this.kind,
    objectHash: objectHash.present ? objectHash.value : this.objectHash,
    etag: etag.present ? etag.value : this.etag,
    partition: partition.present ? partition.value : this.partition,
    observedAt: observedAt ?? this.observedAt,
  );
  ContentRemoteResourceData copyWithCompanion(
    ContentRemoteResourceCompanion data,
  ) {
    return ContentRemoteResourceData(
      targetNamespace: data.targetNamespace.present
          ? data.targetNamespace.value
          : this.targetNamespace,
      href: data.href.present ? data.href.value : this.href,
      kind: data.kind.present ? data.kind.value : this.kind,
      objectHash: data.objectHash.present
          ? data.objectHash.value
          : this.objectHash,
      etag: data.etag.present ? data.etag.value : this.etag,
      partition: data.partition.present ? data.partition.value : this.partition,
      observedAt: data.observedAt.present
          ? data.observedAt.value
          : this.observedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentRemoteResourceData(')
          ..write('targetNamespace: $targetNamespace, ')
          ..write('href: $href, ')
          ..write('kind: $kind, ')
          ..write('objectHash: $objectHash, ')
          ..write('etag: $etag, ')
          ..write('partition: $partition, ')
          ..write('observedAt: $observedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    targetNamespace,
    href,
    kind,
    objectHash,
    etag,
    partition,
    observedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentRemoteResourceData &&
          other.targetNamespace == this.targetNamespace &&
          other.href == this.href &&
          other.kind == this.kind &&
          other.objectHash == this.objectHash &&
          other.etag == this.etag &&
          other.partition == this.partition &&
          other.observedAt == this.observedAt);
}

class ContentRemoteResourceCompanion
    extends UpdateCompanion<ContentRemoteResourceData> {
  final Value<String> targetNamespace;
  final Value<String> href;
  final Value<String> kind;
  final Value<String?> objectHash;
  final Value<String?> etag;
  final Value<String?> partition;
  final Value<String> observedAt;
  final Value<int> rowid;
  const ContentRemoteResourceCompanion({
    this.targetNamespace = const Value.absent(),
    this.href = const Value.absent(),
    this.kind = const Value.absent(),
    this.objectHash = const Value.absent(),
    this.etag = const Value.absent(),
    this.partition = const Value.absent(),
    this.observedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentRemoteResourceCompanion.insert({
    required String targetNamespace,
    required String href,
    required String kind,
    this.objectHash = const Value.absent(),
    this.etag = const Value.absent(),
    this.partition = const Value.absent(),
    required String observedAt,
    this.rowid = const Value.absent(),
  }) : targetNamespace = Value(targetNamespace),
       href = Value(href),
       kind = Value(kind),
       observedAt = Value(observedAt);
  static Insertable<ContentRemoteResourceData> custom({
    Expression<String>? targetNamespace,
    Expression<String>? href,
    Expression<String>? kind,
    Expression<String>? objectHash,
    Expression<String>? etag,
    Expression<String>? partition,
    Expression<String>? observedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (targetNamespace != null) 'target_namespace': targetNamespace,
      if (href != null) 'href': href,
      if (kind != null) 'kind': kind,
      if (objectHash != null) 'object_hash': objectHash,
      if (etag != null) 'etag': etag,
      if (partition != null) 'partition': partition,
      if (observedAt != null) 'observed_at': observedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentRemoteResourceCompanion copyWith({
    Value<String>? targetNamespace,
    Value<String>? href,
    Value<String>? kind,
    Value<String?>? objectHash,
    Value<String?>? etag,
    Value<String?>? partition,
    Value<String>? observedAt,
    Value<int>? rowid,
  }) {
    return ContentRemoteResourceCompanion(
      targetNamespace: targetNamespace ?? this.targetNamespace,
      href: href ?? this.href,
      kind: kind ?? this.kind,
      objectHash: objectHash ?? this.objectHash,
      etag: etag ?? this.etag,
      partition: partition ?? this.partition,
      observedAt: observedAt ?? this.observedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (targetNamespace.present) {
      map['target_namespace'] = Variable<String>(targetNamespace.value);
    }
    if (href.present) {
      map['href'] = Variable<String>(href.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (objectHash.present) {
      map['object_hash'] = Variable<String>(objectHash.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (partition.present) {
      map['partition'] = Variable<String>(partition.value);
    }
    if (observedAt.present) {
      map['observed_at'] = Variable<String>(observedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentRemoteResourceCompanion(')
          ..write('targetNamespace: $targetNamespace, ')
          ..write('href: $href, ')
          ..write('kind: $kind, ')
          ..write('objectHash: $objectHash, ')
          ..write('etag: $etag, ')
          ..write('partition: $partition, ')
          ..write('observedAt: $observedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentRemotePartitionTable extends ContentRemotePartition
    with TableInfo<$ContentRemotePartitionTable, ContentRemotePartitionData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentRemotePartitionTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _targetNamespaceMeta = const VerificationMeta(
    'targetNamespace',
  );
  @override
  late final GeneratedColumn<String> targetNamespace = GeneratedColumn<String>(
    'target_namespace',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partitionMeta = const VerificationMeta(
    'partition',
  );
  @override
  late final GeneratedColumn<String> partition = GeneratedColumn<String>(
    'partition',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncTokenMeta = const VerificationMeta(
    'syncToken',
  );
  @override
  late final GeneratedColumn<String> syncToken = GeneratedColumn<String>(
    'sync_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scanStateMeta = const VerificationMeta(
    'scanState',
  );
  @override
  late final GeneratedColumn<String> scanState = GeneratedColumn<String>(
    'scan_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scannedAtMeta = const VerificationMeta(
    'scannedAt',
  );
  @override
  late final GeneratedColumn<String> scannedAt = GeneratedColumn<String>(
    'scanned_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    targetNamespace,
    partition,
    syncToken,
    scanState,
    scannedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_remote_partition';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentRemotePartitionData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('target_namespace')) {
      context.handle(
        _targetNamespaceMeta,
        targetNamespace.isAcceptableOrUnknown(
          data['target_namespace']!,
          _targetNamespaceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetNamespaceMeta);
    }
    if (data.containsKey('partition')) {
      context.handle(
        _partitionMeta,
        partition.isAcceptableOrUnknown(data['partition']!, _partitionMeta),
      );
    } else if (isInserting) {
      context.missing(_partitionMeta);
    }
    if (data.containsKey('sync_token')) {
      context.handle(
        _syncTokenMeta,
        syncToken.isAcceptableOrUnknown(data['sync_token']!, _syncTokenMeta),
      );
    }
    if (data.containsKey('scan_state')) {
      context.handle(
        _scanStateMeta,
        scanState.isAcceptableOrUnknown(data['scan_state']!, _scanStateMeta),
      );
    } else if (isInserting) {
      context.missing(_scanStateMeta);
    }
    if (data.containsKey('scanned_at')) {
      context.handle(
        _scannedAtMeta,
        scannedAt.isAcceptableOrUnknown(data['scanned_at']!, _scannedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {targetNamespace, partition};
  @override
  ContentRemotePartitionData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentRemotePartitionData(
      targetNamespace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_namespace'],
      )!,
      partition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}partition'],
      )!,
      syncToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_token'],
      ),
      scanState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_state'],
      )!,
      scannedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scanned_at'],
      ),
    );
  }

  @override
  $ContentRemotePartitionTable createAlias(String alias) {
    return $ContentRemotePartitionTable(attachedDatabase, alias);
  }
}

class ContentRemotePartitionData extends DataClass
    implements Insertable<ContentRemotePartitionData> {
  final String targetNamespace;
  final String partition;
  final String? syncToken;
  final String scanState;
  final String? scannedAt;
  const ContentRemotePartitionData({
    required this.targetNamespace,
    required this.partition,
    this.syncToken,
    required this.scanState,
    this.scannedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['target_namespace'] = Variable<String>(targetNamespace);
    map['partition'] = Variable<String>(partition);
    if (!nullToAbsent || syncToken != null) {
      map['sync_token'] = Variable<String>(syncToken);
    }
    map['scan_state'] = Variable<String>(scanState);
    if (!nullToAbsent || scannedAt != null) {
      map['scanned_at'] = Variable<String>(scannedAt);
    }
    return map;
  }

  ContentRemotePartitionCompanion toCompanion(bool nullToAbsent) {
    return ContentRemotePartitionCompanion(
      targetNamespace: Value(targetNamespace),
      partition: Value(partition),
      syncToken: syncToken == null && nullToAbsent
          ? const Value.absent()
          : Value(syncToken),
      scanState: Value(scanState),
      scannedAt: scannedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(scannedAt),
    );
  }

  factory ContentRemotePartitionData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentRemotePartitionData(
      targetNamespace: serializer.fromJson<String>(json['targetNamespace']),
      partition: serializer.fromJson<String>(json['partition']),
      syncToken: serializer.fromJson<String?>(json['syncToken']),
      scanState: serializer.fromJson<String>(json['scanState']),
      scannedAt: serializer.fromJson<String?>(json['scannedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'targetNamespace': serializer.toJson<String>(targetNamespace),
      'partition': serializer.toJson<String>(partition),
      'syncToken': serializer.toJson<String?>(syncToken),
      'scanState': serializer.toJson<String>(scanState),
      'scannedAt': serializer.toJson<String?>(scannedAt),
    };
  }

  ContentRemotePartitionData copyWith({
    String? targetNamespace,
    String? partition,
    Value<String?> syncToken = const Value.absent(),
    String? scanState,
    Value<String?> scannedAt = const Value.absent(),
  }) => ContentRemotePartitionData(
    targetNamespace: targetNamespace ?? this.targetNamespace,
    partition: partition ?? this.partition,
    syncToken: syncToken.present ? syncToken.value : this.syncToken,
    scanState: scanState ?? this.scanState,
    scannedAt: scannedAt.present ? scannedAt.value : this.scannedAt,
  );
  ContentRemotePartitionData copyWithCompanion(
    ContentRemotePartitionCompanion data,
  ) {
    return ContentRemotePartitionData(
      targetNamespace: data.targetNamespace.present
          ? data.targetNamespace.value
          : this.targetNamespace,
      partition: data.partition.present ? data.partition.value : this.partition,
      syncToken: data.syncToken.present ? data.syncToken.value : this.syncToken,
      scanState: data.scanState.present ? data.scanState.value : this.scanState,
      scannedAt: data.scannedAt.present ? data.scannedAt.value : this.scannedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentRemotePartitionData(')
          ..write('targetNamespace: $targetNamespace, ')
          ..write('partition: $partition, ')
          ..write('syncToken: $syncToken, ')
          ..write('scanState: $scanState, ')
          ..write('scannedAt: $scannedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(targetNamespace, partition, syncToken, scanState, scannedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentRemotePartitionData &&
          other.targetNamespace == this.targetNamespace &&
          other.partition == this.partition &&
          other.syncToken == this.syncToken &&
          other.scanState == this.scanState &&
          other.scannedAt == this.scannedAt);
}

class ContentRemotePartitionCompanion
    extends UpdateCompanion<ContentRemotePartitionData> {
  final Value<String> targetNamespace;
  final Value<String> partition;
  final Value<String?> syncToken;
  final Value<String> scanState;
  final Value<String?> scannedAt;
  final Value<int> rowid;
  const ContentRemotePartitionCompanion({
    this.targetNamespace = const Value.absent(),
    this.partition = const Value.absent(),
    this.syncToken = const Value.absent(),
    this.scanState = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentRemotePartitionCompanion.insert({
    required String targetNamespace,
    required String partition,
    this.syncToken = const Value.absent(),
    required String scanState,
    this.scannedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : targetNamespace = Value(targetNamespace),
       partition = Value(partition),
       scanState = Value(scanState);
  static Insertable<ContentRemotePartitionData> custom({
    Expression<String>? targetNamespace,
    Expression<String>? partition,
    Expression<String>? syncToken,
    Expression<String>? scanState,
    Expression<String>? scannedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (targetNamespace != null) 'target_namespace': targetNamespace,
      if (partition != null) 'partition': partition,
      if (syncToken != null) 'sync_token': syncToken,
      if (scanState != null) 'scan_state': scanState,
      if (scannedAt != null) 'scanned_at': scannedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentRemotePartitionCompanion copyWith({
    Value<String>? targetNamespace,
    Value<String>? partition,
    Value<String?>? syncToken,
    Value<String>? scanState,
    Value<String?>? scannedAt,
    Value<int>? rowid,
  }) {
    return ContentRemotePartitionCompanion(
      targetNamespace: targetNamespace ?? this.targetNamespace,
      partition: partition ?? this.partition,
      syncToken: syncToken ?? this.syncToken,
      scanState: scanState ?? this.scanState,
      scannedAt: scannedAt ?? this.scannedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (targetNamespace.present) {
      map['target_namespace'] = Variable<String>(targetNamespace.value);
    }
    if (partition.present) {
      map['partition'] = Variable<String>(partition.value);
    }
    if (syncToken.present) {
      map['sync_token'] = Variable<String>(syncToken.value);
    }
    if (scanState.present) {
      map['scan_state'] = Variable<String>(scanState.value);
    }
    if (scannedAt.present) {
      map['scanned_at'] = Variable<String>(scannedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentRemotePartitionCompanion(')
          ..write('targetNamespace: $targetNamespace, ')
          ..write('partition: $partition, ')
          ..write('syncToken: $syncToken, ')
          ..write('scanState: $scanState, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentManifestTable extends ContentManifest
    with TableInfo<$ContentManifestTable, ContentManifestData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentManifestTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _targetNamespaceMeta = const VerificationMeta(
    'targetNamespace',
  );
  @override
  late final GeneratedColumn<String> targetNamespace = GeneratedColumn<String>(
    'target_namespace',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manifestIdMeta = const VerificationMeta(
    'manifestId',
  );
  @override
  late final GeneratedColumn<String> manifestId = GeneratedColumn<String>(
    'manifest_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
    'gid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _representationMeta = const VerificationMeta(
    'representation',
  );
  @override
  late final GeneratedColumn<String> representation = GeneratedColumn<String>(
    'representation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _galleryUrlMeta = const VerificationMeta(
    'galleryUrl',
  );
  @override
  late final GeneratedColumn<String> galleryUrl = GeneratedColumn<String>(
    'gallery_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _portableJsonMeta = const VerificationMeta(
    'portableJson',
  );
  @override
  late final GeneratedColumn<String> portableJson = GeneratedColumn<String>(
    'portable_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<String> importedAt = GeneratedColumn<String>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    targetNamespace,
    manifestId,
    gid,
    representation,
    title,
    galleryUrl,
    portableJson,
    importedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_manifest';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentManifestData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('target_namespace')) {
      context.handle(
        _targetNamespaceMeta,
        targetNamespace.isAcceptableOrUnknown(
          data['target_namespace']!,
          _targetNamespaceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetNamespaceMeta);
    }
    if (data.containsKey('manifest_id')) {
      context.handle(
        _manifestIdMeta,
        manifestId.isAcceptableOrUnknown(data['manifest_id']!, _manifestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_manifestIdMeta);
    }
    if (data.containsKey('gid')) {
      context.handle(
        _gidMeta,
        gid.isAcceptableOrUnknown(data['gid']!, _gidMeta),
      );
    } else if (isInserting) {
      context.missing(_gidMeta);
    }
    if (data.containsKey('representation')) {
      context.handle(
        _representationMeta,
        representation.isAcceptableOrUnknown(
          data['representation']!,
          _representationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_representationMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('gallery_url')) {
      context.handle(
        _galleryUrlMeta,
        galleryUrl.isAcceptableOrUnknown(data['gallery_url']!, _galleryUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_galleryUrlMeta);
    }
    if (data.containsKey('portable_json')) {
      context.handle(
        _portableJsonMeta,
        portableJson.isAcceptableOrUnknown(
          data['portable_json']!,
          _portableJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_portableJsonMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {targetNamespace, manifestId};
  @override
  ContentManifestData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentManifestData(
      targetNamespace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_namespace'],
      )!,
      manifestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_id'],
      )!,
      gid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gid'],
      )!,
      representation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}representation'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      galleryUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gallery_url'],
      )!,
      portableJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}portable_json'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imported_at'],
      )!,
    );
  }

  @override
  $ContentManifestTable createAlias(String alias) {
    return $ContentManifestTable(attachedDatabase, alias);
  }
}

class ContentManifestData extends DataClass
    implements Insertable<ContentManifestData> {
  final String targetNamespace;
  final String manifestId;
  final int gid;
  final String representation;
  final String title;
  final String galleryUrl;
  final String portableJson;
  final String importedAt;
  const ContentManifestData({
    required this.targetNamespace,
    required this.manifestId,
    required this.gid,
    required this.representation,
    required this.title,
    required this.galleryUrl,
    required this.portableJson,
    required this.importedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['target_namespace'] = Variable<String>(targetNamespace);
    map['manifest_id'] = Variable<String>(manifestId);
    map['gid'] = Variable<int>(gid);
    map['representation'] = Variable<String>(representation);
    map['title'] = Variable<String>(title);
    map['gallery_url'] = Variable<String>(galleryUrl);
    map['portable_json'] = Variable<String>(portableJson);
    map['imported_at'] = Variable<String>(importedAt);
    return map;
  }

  ContentManifestCompanion toCompanion(bool nullToAbsent) {
    return ContentManifestCompanion(
      targetNamespace: Value(targetNamespace),
      manifestId: Value(manifestId),
      gid: Value(gid),
      representation: Value(representation),
      title: Value(title),
      galleryUrl: Value(galleryUrl),
      portableJson: Value(portableJson),
      importedAt: Value(importedAt),
    );
  }

  factory ContentManifestData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentManifestData(
      targetNamespace: serializer.fromJson<String>(json['targetNamespace']),
      manifestId: serializer.fromJson<String>(json['manifestId']),
      gid: serializer.fromJson<int>(json['gid']),
      representation: serializer.fromJson<String>(json['representation']),
      title: serializer.fromJson<String>(json['title']),
      galleryUrl: serializer.fromJson<String>(json['galleryUrl']),
      portableJson: serializer.fromJson<String>(json['portableJson']),
      importedAt: serializer.fromJson<String>(json['importedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'targetNamespace': serializer.toJson<String>(targetNamespace),
      'manifestId': serializer.toJson<String>(manifestId),
      'gid': serializer.toJson<int>(gid),
      'representation': serializer.toJson<String>(representation),
      'title': serializer.toJson<String>(title),
      'galleryUrl': serializer.toJson<String>(galleryUrl),
      'portableJson': serializer.toJson<String>(portableJson),
      'importedAt': serializer.toJson<String>(importedAt),
    };
  }

  ContentManifestData copyWith({
    String? targetNamespace,
    String? manifestId,
    int? gid,
    String? representation,
    String? title,
    String? galleryUrl,
    String? portableJson,
    String? importedAt,
  }) => ContentManifestData(
    targetNamespace: targetNamespace ?? this.targetNamespace,
    manifestId: manifestId ?? this.manifestId,
    gid: gid ?? this.gid,
    representation: representation ?? this.representation,
    title: title ?? this.title,
    galleryUrl: galleryUrl ?? this.galleryUrl,
    portableJson: portableJson ?? this.portableJson,
    importedAt: importedAt ?? this.importedAt,
  );
  ContentManifestData copyWithCompanion(ContentManifestCompanion data) {
    return ContentManifestData(
      targetNamespace: data.targetNamespace.present
          ? data.targetNamespace.value
          : this.targetNamespace,
      manifestId: data.manifestId.present
          ? data.manifestId.value
          : this.manifestId,
      gid: data.gid.present ? data.gid.value : this.gid,
      representation: data.representation.present
          ? data.representation.value
          : this.representation,
      title: data.title.present ? data.title.value : this.title,
      galleryUrl: data.galleryUrl.present
          ? data.galleryUrl.value
          : this.galleryUrl,
      portableJson: data.portableJson.present
          ? data.portableJson.value
          : this.portableJson,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentManifestData(')
          ..write('targetNamespace: $targetNamespace, ')
          ..write('manifestId: $manifestId, ')
          ..write('gid: $gid, ')
          ..write('representation: $representation, ')
          ..write('title: $title, ')
          ..write('galleryUrl: $galleryUrl, ')
          ..write('portableJson: $portableJson, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    targetNamespace,
    manifestId,
    gid,
    representation,
    title,
    galleryUrl,
    portableJson,
    importedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentManifestData &&
          other.targetNamespace == this.targetNamespace &&
          other.manifestId == this.manifestId &&
          other.gid == this.gid &&
          other.representation == this.representation &&
          other.title == this.title &&
          other.galleryUrl == this.galleryUrl &&
          other.portableJson == this.portableJson &&
          other.importedAt == this.importedAt);
}

class ContentManifestCompanion extends UpdateCompanion<ContentManifestData> {
  final Value<String> targetNamespace;
  final Value<String> manifestId;
  final Value<int> gid;
  final Value<String> representation;
  final Value<String> title;
  final Value<String> galleryUrl;
  final Value<String> portableJson;
  final Value<String> importedAt;
  final Value<int> rowid;
  const ContentManifestCompanion({
    this.targetNamespace = const Value.absent(),
    this.manifestId = const Value.absent(),
    this.gid = const Value.absent(),
    this.representation = const Value.absent(),
    this.title = const Value.absent(),
    this.galleryUrl = const Value.absent(),
    this.portableJson = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentManifestCompanion.insert({
    required String targetNamespace,
    required String manifestId,
    required int gid,
    required String representation,
    required String title,
    required String galleryUrl,
    required String portableJson,
    required String importedAt,
    this.rowid = const Value.absent(),
  }) : targetNamespace = Value(targetNamespace),
       manifestId = Value(manifestId),
       gid = Value(gid),
       representation = Value(representation),
       title = Value(title),
       galleryUrl = Value(galleryUrl),
       portableJson = Value(portableJson),
       importedAt = Value(importedAt);
  static Insertable<ContentManifestData> custom({
    Expression<String>? targetNamespace,
    Expression<String>? manifestId,
    Expression<int>? gid,
    Expression<String>? representation,
    Expression<String>? title,
    Expression<String>? galleryUrl,
    Expression<String>? portableJson,
    Expression<String>? importedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (targetNamespace != null) 'target_namespace': targetNamespace,
      if (manifestId != null) 'manifest_id': manifestId,
      if (gid != null) 'gid': gid,
      if (representation != null) 'representation': representation,
      if (title != null) 'title': title,
      if (galleryUrl != null) 'gallery_url': galleryUrl,
      if (portableJson != null) 'portable_json': portableJson,
      if (importedAt != null) 'imported_at': importedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentManifestCompanion copyWith({
    Value<String>? targetNamespace,
    Value<String>? manifestId,
    Value<int>? gid,
    Value<String>? representation,
    Value<String>? title,
    Value<String>? galleryUrl,
    Value<String>? portableJson,
    Value<String>? importedAt,
    Value<int>? rowid,
  }) {
    return ContentManifestCompanion(
      targetNamespace: targetNamespace ?? this.targetNamespace,
      manifestId: manifestId ?? this.manifestId,
      gid: gid ?? this.gid,
      representation: representation ?? this.representation,
      title: title ?? this.title,
      galleryUrl: galleryUrl ?? this.galleryUrl,
      portableJson: portableJson ?? this.portableJson,
      importedAt: importedAt ?? this.importedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (targetNamespace.present) {
      map['target_namespace'] = Variable<String>(targetNamespace.value);
    }
    if (manifestId.present) {
      map['manifest_id'] = Variable<String>(manifestId.value);
    }
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (representation.present) {
      map['representation'] = Variable<String>(representation.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (galleryUrl.present) {
      map['gallery_url'] = Variable<String>(galleryUrl.value);
    }
    if (portableJson.present) {
      map['portable_json'] = Variable<String>(portableJson.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<String>(importedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentManifestCompanion(')
          ..write('targetNamespace: $targetNamespace, ')
          ..write('manifestId: $manifestId, ')
          ..write('gid: $gid, ')
          ..write('representation: $representation, ')
          ..write('title: $title, ')
          ..write('galleryUrl: $galleryUrl, ')
          ..write('portableJson: $portableJson, ')
          ..write('importedAt: $importedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentObjectRepresentationTable extends ContentObjectRepresentation
    with
        TableInfo<
          $ContentObjectRepresentationTable,
          ContentObjectRepresentationData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentObjectRepresentationTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _targetNamespaceMeta = const VerificationMeta(
    'targetNamespace',
  );
  @override
  late final GeneratedColumn<String> targetNamespace = GeneratedColumn<String>(
    'target_namespace',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawHashMeta = const VerificationMeta(
    'rawHash',
  );
  @override
  late final GeneratedColumn<String> rawHash = GeneratedColumn<String>(
    'raw_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _objectHashMeta = const VerificationMeta(
    'objectHash',
  );
  @override
  late final GeneratedColumn<String> objectHash = GeneratedColumn<String>(
    'object_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codecProfileMeta = const VerificationMeta(
    'codecProfile',
  );
  @override
  late final GeneratedColumn<String> codecProfile = GeneratedColumn<String>(
    'codec_profile',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storedLengthMeta = const VerificationMeta(
    'storedLength',
  );
  @override
  late final GeneratedColumn<int> storedLength = GeneratedColumn<int>(
    'stored_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    targetNamespace,
    rawHash,
    objectHash,
    codecProfile,
    storedLength,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_object_representation';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentObjectRepresentationData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('target_namespace')) {
      context.handle(
        _targetNamespaceMeta,
        targetNamespace.isAcceptableOrUnknown(
          data['target_namespace']!,
          _targetNamespaceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetNamespaceMeta);
    }
    if (data.containsKey('raw_hash')) {
      context.handle(
        _rawHashMeta,
        rawHash.isAcceptableOrUnknown(data['raw_hash']!, _rawHashMeta),
      );
    } else if (isInserting) {
      context.missing(_rawHashMeta);
    }
    if (data.containsKey('object_hash')) {
      context.handle(
        _objectHashMeta,
        objectHash.isAcceptableOrUnknown(data['object_hash']!, _objectHashMeta),
      );
    } else if (isInserting) {
      context.missing(_objectHashMeta);
    }
    if (data.containsKey('codec_profile')) {
      context.handle(
        _codecProfileMeta,
        codecProfile.isAcceptableOrUnknown(
          data['codec_profile']!,
          _codecProfileMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_codecProfileMeta);
    }
    if (data.containsKey('stored_length')) {
      context.handle(
        _storedLengthMeta,
        storedLength.isAcceptableOrUnknown(
          data['stored_length']!,
          _storedLengthMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_storedLengthMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    targetNamespace,
    rawHash,
    objectHash,
  };
  @override
  ContentObjectRepresentationData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentObjectRepresentationData(
      targetNamespace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_namespace'],
      )!,
      rawHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_hash'],
      )!,
      objectHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}object_hash'],
      )!,
      codecProfile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}codec_profile'],
      )!,
      storedLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stored_length'],
      )!,
    );
  }

  @override
  $ContentObjectRepresentationTable createAlias(String alias) {
    return $ContentObjectRepresentationTable(attachedDatabase, alias);
  }
}

class ContentObjectRepresentationData extends DataClass
    implements Insertable<ContentObjectRepresentationData> {
  final String targetNamespace;
  final String rawHash;
  final String objectHash;
  final String codecProfile;
  final int storedLength;
  const ContentObjectRepresentationData({
    required this.targetNamespace,
    required this.rawHash,
    required this.objectHash,
    required this.codecProfile,
    required this.storedLength,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['target_namespace'] = Variable<String>(targetNamespace);
    map['raw_hash'] = Variable<String>(rawHash);
    map['object_hash'] = Variable<String>(objectHash);
    map['codec_profile'] = Variable<String>(codecProfile);
    map['stored_length'] = Variable<int>(storedLength);
    return map;
  }

  ContentObjectRepresentationCompanion toCompanion(bool nullToAbsent) {
    return ContentObjectRepresentationCompanion(
      targetNamespace: Value(targetNamespace),
      rawHash: Value(rawHash),
      objectHash: Value(objectHash),
      codecProfile: Value(codecProfile),
      storedLength: Value(storedLength),
    );
  }

  factory ContentObjectRepresentationData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentObjectRepresentationData(
      targetNamespace: serializer.fromJson<String>(json['targetNamespace']),
      rawHash: serializer.fromJson<String>(json['rawHash']),
      objectHash: serializer.fromJson<String>(json['objectHash']),
      codecProfile: serializer.fromJson<String>(json['codecProfile']),
      storedLength: serializer.fromJson<int>(json['storedLength']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'targetNamespace': serializer.toJson<String>(targetNamespace),
      'rawHash': serializer.toJson<String>(rawHash),
      'objectHash': serializer.toJson<String>(objectHash),
      'codecProfile': serializer.toJson<String>(codecProfile),
      'storedLength': serializer.toJson<int>(storedLength),
    };
  }

  ContentObjectRepresentationData copyWith({
    String? targetNamespace,
    String? rawHash,
    String? objectHash,
    String? codecProfile,
    int? storedLength,
  }) => ContentObjectRepresentationData(
    targetNamespace: targetNamespace ?? this.targetNamespace,
    rawHash: rawHash ?? this.rawHash,
    objectHash: objectHash ?? this.objectHash,
    codecProfile: codecProfile ?? this.codecProfile,
    storedLength: storedLength ?? this.storedLength,
  );
  ContentObjectRepresentationData copyWithCompanion(
    ContentObjectRepresentationCompanion data,
  ) {
    return ContentObjectRepresentationData(
      targetNamespace: data.targetNamespace.present
          ? data.targetNamespace.value
          : this.targetNamespace,
      rawHash: data.rawHash.present ? data.rawHash.value : this.rawHash,
      objectHash: data.objectHash.present
          ? data.objectHash.value
          : this.objectHash,
      codecProfile: data.codecProfile.present
          ? data.codecProfile.value
          : this.codecProfile,
      storedLength: data.storedLength.present
          ? data.storedLength.value
          : this.storedLength,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentObjectRepresentationData(')
          ..write('targetNamespace: $targetNamespace, ')
          ..write('rawHash: $rawHash, ')
          ..write('objectHash: $objectHash, ')
          ..write('codecProfile: $codecProfile, ')
          ..write('storedLength: $storedLength')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    targetNamespace,
    rawHash,
    objectHash,
    codecProfile,
    storedLength,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentObjectRepresentationData &&
          other.targetNamespace == this.targetNamespace &&
          other.rawHash == this.rawHash &&
          other.objectHash == this.objectHash &&
          other.codecProfile == this.codecProfile &&
          other.storedLength == this.storedLength);
}

class ContentObjectRepresentationCompanion
    extends UpdateCompanion<ContentObjectRepresentationData> {
  final Value<String> targetNamespace;
  final Value<String> rawHash;
  final Value<String> objectHash;
  final Value<String> codecProfile;
  final Value<int> storedLength;
  final Value<int> rowid;
  const ContentObjectRepresentationCompanion({
    this.targetNamespace = const Value.absent(),
    this.rawHash = const Value.absent(),
    this.objectHash = const Value.absent(),
    this.codecProfile = const Value.absent(),
    this.storedLength = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentObjectRepresentationCompanion.insert({
    required String targetNamespace,
    required String rawHash,
    required String objectHash,
    required String codecProfile,
    required int storedLength,
    this.rowid = const Value.absent(),
  }) : targetNamespace = Value(targetNamespace),
       rawHash = Value(rawHash),
       objectHash = Value(objectHash),
       codecProfile = Value(codecProfile),
       storedLength = Value(storedLength);
  static Insertable<ContentObjectRepresentationData> custom({
    Expression<String>? targetNamespace,
    Expression<String>? rawHash,
    Expression<String>? objectHash,
    Expression<String>? codecProfile,
    Expression<int>? storedLength,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (targetNamespace != null) 'target_namespace': targetNamespace,
      if (rawHash != null) 'raw_hash': rawHash,
      if (objectHash != null) 'object_hash': objectHash,
      if (codecProfile != null) 'codec_profile': codecProfile,
      if (storedLength != null) 'stored_length': storedLength,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentObjectRepresentationCompanion copyWith({
    Value<String>? targetNamespace,
    Value<String>? rawHash,
    Value<String>? objectHash,
    Value<String>? codecProfile,
    Value<int>? storedLength,
    Value<int>? rowid,
  }) {
    return ContentObjectRepresentationCompanion(
      targetNamespace: targetNamespace ?? this.targetNamespace,
      rawHash: rawHash ?? this.rawHash,
      objectHash: objectHash ?? this.objectHash,
      codecProfile: codecProfile ?? this.codecProfile,
      storedLength: storedLength ?? this.storedLength,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (targetNamespace.present) {
      map['target_namespace'] = Variable<String>(targetNamespace.value);
    }
    if (rawHash.present) {
      map['raw_hash'] = Variable<String>(rawHash.value);
    }
    if (objectHash.present) {
      map['object_hash'] = Variable<String>(objectHash.value);
    }
    if (codecProfile.present) {
      map['codec_profile'] = Variable<String>(codecProfile.value);
    }
    if (storedLength.present) {
      map['stored_length'] = Variable<int>(storedLength.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentObjectRepresentationCompanion(')
          ..write('targetNamespace: $targetNamespace, ')
          ..write('rawHash: $rawHash, ')
          ..write('objectHash: $objectHash, ')
          ..write('codecProfile: $codecProfile, ')
          ..write('storedLength: $storedLength, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentWorkItemTable extends ContentWorkItem
    with TableInfo<$ContentWorkItemTable, ContentWorkItemData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentWorkItemTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _workItemIdMeta = const VerificationMeta(
    'workItemId',
  );
  @override
  late final GeneratedColumn<String> workItemId = GeneratedColumn<String>(
    'work_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetNamespaceMeta = const VerificationMeta(
    'targetNamespace',
  );
  @override
  late final GeneratedColumn<String> targetNamespace = GeneratedColumn<String>(
    'target_namespace',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _copyIdMeta = const VerificationMeta('copyId');
  @override
  late final GeneratedColumn<String> copyId = GeneratedColumn<String>(
    'copy_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputManifestIdMeta = const VerificationMeta(
    'inputManifestId',
  );
  @override
  late final GeneratedColumn<String> inputManifestId = GeneratedColumn<String>(
    'input_manifest_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inputJsonMeta = const VerificationMeta(
    'inputJson',
  );
  @override
  late final GeneratedColumn<String> inputJson = GeneratedColumn<String>(
    'input_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localArtifactPathMeta = const VerificationMeta(
    'localArtifactPath',
  );
  @override
  late final GeneratedColumn<String> localArtifactPath =
      GeneratedColumn<String>(
        'local_artifact_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _remoteDestinationMeta = const VerificationMeta(
    'remoteDestination',
  );
  @override
  late final GeneratedColumn<String> remoteDestination =
      GeneratedColumn<String>(
        'remote_destination',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _artifactsJsonMeta = const VerificationMeta(
    'artifactsJson',
  );
  @override
  late final GeneratedColumn<String> artifactsJson = GeneratedColumn<String>(
    'artifacts_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _committedObjectsJsonMeta =
      const VerificationMeta('committedObjectsJson');
  @override
  late final GeneratedColumn<String> committedObjectsJson =
      GeneratedColumn<String>(
        'committed_objects_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _pendingManifestIdMeta = const VerificationMeta(
    'pendingManifestId',
  );
  @override
  late final GeneratedColumn<String> pendingManifestId =
      GeneratedColumn<String>(
        'pending_manifest_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _finishActionMeta = const VerificationMeta(
    'finishAction',
  );
  @override
  late final GeneratedColumn<String> finishAction = GeneratedColumn<String>(
    'finish_action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('keep'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    workItemId,
    targetNamespace,
    copyId,
    kind,
    state,
    inputManifestId,
    inputJson,
    localArtifactPath,
    remoteDestination,
    artifactsJson,
    committedObjectsJson,
    pendingManifestId,
    source,
    finishAction,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_work_item';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentWorkItemData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('work_item_id')) {
      context.handle(
        _workItemIdMeta,
        workItemId.isAcceptableOrUnknown(
          data['work_item_id']!,
          _workItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workItemIdMeta);
    }
    if (data.containsKey('target_namespace')) {
      context.handle(
        _targetNamespaceMeta,
        targetNamespace.isAcceptableOrUnknown(
          data['target_namespace']!,
          _targetNamespaceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetNamespaceMeta);
    }
    if (data.containsKey('copy_id')) {
      context.handle(
        _copyIdMeta,
        copyId.isAcceptableOrUnknown(data['copy_id']!, _copyIdMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('input_manifest_id')) {
      context.handle(
        _inputManifestIdMeta,
        inputManifestId.isAcceptableOrUnknown(
          data['input_manifest_id']!,
          _inputManifestIdMeta,
        ),
      );
    }
    if (data.containsKey('input_json')) {
      context.handle(
        _inputJsonMeta,
        inputJson.isAcceptableOrUnknown(data['input_json']!, _inputJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_inputJsonMeta);
    }
    if (data.containsKey('local_artifact_path')) {
      context.handle(
        _localArtifactPathMeta,
        localArtifactPath.isAcceptableOrUnknown(
          data['local_artifact_path']!,
          _localArtifactPathMeta,
        ),
      );
    }
    if (data.containsKey('remote_destination')) {
      context.handle(
        _remoteDestinationMeta,
        remoteDestination.isAcceptableOrUnknown(
          data['remote_destination']!,
          _remoteDestinationMeta,
        ),
      );
    }
    if (data.containsKey('artifacts_json')) {
      context.handle(
        _artifactsJsonMeta,
        artifactsJson.isAcceptableOrUnknown(
          data['artifacts_json']!,
          _artifactsJsonMeta,
        ),
      );
    }
    if (data.containsKey('committed_objects_json')) {
      context.handle(
        _committedObjectsJsonMeta,
        committedObjectsJson.isAcceptableOrUnknown(
          data['committed_objects_json']!,
          _committedObjectsJsonMeta,
        ),
      );
    }
    if (data.containsKey('pending_manifest_id')) {
      context.handle(
        _pendingManifestIdMeta,
        pendingManifestId.isAcceptableOrUnknown(
          data['pending_manifest_id']!,
          _pendingManifestIdMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('finish_action')) {
      context.handle(
        _finishActionMeta,
        finishAction.isAcceptableOrUnknown(
          data['finish_action']!,
          _finishActionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {workItemId};
  @override
  ContentWorkItemData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentWorkItemData(
      workItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_item_id'],
      )!,
      targetNamespace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_namespace'],
      )!,
      copyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}copy_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      inputManifestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_manifest_id'],
      ),
      inputJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_json'],
      )!,
      localArtifactPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_artifact_path'],
      ),
      remoteDestination: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_destination'],
      ),
      artifactsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artifacts_json'],
      )!,
      committedObjectsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}committed_objects_json'],
      )!,
      pendingManifestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_manifest_id'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      finishAction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}finish_action'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ContentWorkItemTable createAlias(String alias) {
    return $ContentWorkItemTable(attachedDatabase, alias);
  }
}

class ContentWorkItemData extends DataClass
    implements Insertable<ContentWorkItemData> {
  final String workItemId;
  final String targetNamespace;
  final String? copyId;
  final String kind;
  final String state;
  final String? inputManifestId;
  final String inputJson;
  final String? localArtifactPath;
  final String? remoteDestination;
  final String artifactsJson;
  final String committedObjectsJson;
  final String? pendingManifestId;
  final String source;
  final String finishAction;
  final String createdAt;
  final String updatedAt;
  const ContentWorkItemData({
    required this.workItemId,
    required this.targetNamespace,
    this.copyId,
    required this.kind,
    required this.state,
    this.inputManifestId,
    required this.inputJson,
    this.localArtifactPath,
    this.remoteDestination,
    required this.artifactsJson,
    required this.committedObjectsJson,
    this.pendingManifestId,
    required this.source,
    required this.finishAction,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['work_item_id'] = Variable<String>(workItemId);
    map['target_namespace'] = Variable<String>(targetNamespace);
    if (!nullToAbsent || copyId != null) {
      map['copy_id'] = Variable<String>(copyId);
    }
    map['kind'] = Variable<String>(kind);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || inputManifestId != null) {
      map['input_manifest_id'] = Variable<String>(inputManifestId);
    }
    map['input_json'] = Variable<String>(inputJson);
    if (!nullToAbsent || localArtifactPath != null) {
      map['local_artifact_path'] = Variable<String>(localArtifactPath);
    }
    if (!nullToAbsent || remoteDestination != null) {
      map['remote_destination'] = Variable<String>(remoteDestination);
    }
    map['artifacts_json'] = Variable<String>(artifactsJson);
    map['committed_objects_json'] = Variable<String>(committedObjectsJson);
    if (!nullToAbsent || pendingManifestId != null) {
      map['pending_manifest_id'] = Variable<String>(pendingManifestId);
    }
    map['source'] = Variable<String>(source);
    map['finish_action'] = Variable<String>(finishAction);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  ContentWorkItemCompanion toCompanion(bool nullToAbsent) {
    return ContentWorkItemCompanion(
      workItemId: Value(workItemId),
      targetNamespace: Value(targetNamespace),
      copyId: copyId == null && nullToAbsent
          ? const Value.absent()
          : Value(copyId),
      kind: Value(kind),
      state: Value(state),
      inputManifestId: inputManifestId == null && nullToAbsent
          ? const Value.absent()
          : Value(inputManifestId),
      inputJson: Value(inputJson),
      localArtifactPath: localArtifactPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localArtifactPath),
      remoteDestination: remoteDestination == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteDestination),
      artifactsJson: Value(artifactsJson),
      committedObjectsJson: Value(committedObjectsJson),
      pendingManifestId: pendingManifestId == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingManifestId),
      source: Value(source),
      finishAction: Value(finishAction),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ContentWorkItemData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentWorkItemData(
      workItemId: serializer.fromJson<String>(json['workItemId']),
      targetNamespace: serializer.fromJson<String>(json['targetNamespace']),
      copyId: serializer.fromJson<String?>(json['copyId']),
      kind: serializer.fromJson<String>(json['kind']),
      state: serializer.fromJson<String>(json['state']),
      inputManifestId: serializer.fromJson<String?>(json['inputManifestId']),
      inputJson: serializer.fromJson<String>(json['inputJson']),
      localArtifactPath: serializer.fromJson<String?>(
        json['localArtifactPath'],
      ),
      remoteDestination: serializer.fromJson<String?>(
        json['remoteDestination'],
      ),
      artifactsJson: serializer.fromJson<String>(json['artifactsJson']),
      committedObjectsJson: serializer.fromJson<String>(
        json['committedObjectsJson'],
      ),
      pendingManifestId: serializer.fromJson<String?>(
        json['pendingManifestId'],
      ),
      source: serializer.fromJson<String>(json['source']),
      finishAction: serializer.fromJson<String>(json['finishAction']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'workItemId': serializer.toJson<String>(workItemId),
      'targetNamespace': serializer.toJson<String>(targetNamespace),
      'copyId': serializer.toJson<String?>(copyId),
      'kind': serializer.toJson<String>(kind),
      'state': serializer.toJson<String>(state),
      'inputManifestId': serializer.toJson<String?>(inputManifestId),
      'inputJson': serializer.toJson<String>(inputJson),
      'localArtifactPath': serializer.toJson<String?>(localArtifactPath),
      'remoteDestination': serializer.toJson<String?>(remoteDestination),
      'artifactsJson': serializer.toJson<String>(artifactsJson),
      'committedObjectsJson': serializer.toJson<String>(committedObjectsJson),
      'pendingManifestId': serializer.toJson<String?>(pendingManifestId),
      'source': serializer.toJson<String>(source),
      'finishAction': serializer.toJson<String>(finishAction),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  ContentWorkItemData copyWith({
    String? workItemId,
    String? targetNamespace,
    Value<String?> copyId = const Value.absent(),
    String? kind,
    String? state,
    Value<String?> inputManifestId = const Value.absent(),
    String? inputJson,
    Value<String?> localArtifactPath = const Value.absent(),
    Value<String?> remoteDestination = const Value.absent(),
    String? artifactsJson,
    String? committedObjectsJson,
    Value<String?> pendingManifestId = const Value.absent(),
    String? source,
    String? finishAction,
    String? createdAt,
    String? updatedAt,
  }) => ContentWorkItemData(
    workItemId: workItemId ?? this.workItemId,
    targetNamespace: targetNamespace ?? this.targetNamespace,
    copyId: copyId.present ? copyId.value : this.copyId,
    kind: kind ?? this.kind,
    state: state ?? this.state,
    inputManifestId: inputManifestId.present
        ? inputManifestId.value
        : this.inputManifestId,
    inputJson: inputJson ?? this.inputJson,
    localArtifactPath: localArtifactPath.present
        ? localArtifactPath.value
        : this.localArtifactPath,
    remoteDestination: remoteDestination.present
        ? remoteDestination.value
        : this.remoteDestination,
    artifactsJson: artifactsJson ?? this.artifactsJson,
    committedObjectsJson: committedObjectsJson ?? this.committedObjectsJson,
    pendingManifestId: pendingManifestId.present
        ? pendingManifestId.value
        : this.pendingManifestId,
    source: source ?? this.source,
    finishAction: finishAction ?? this.finishAction,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ContentWorkItemData copyWithCompanion(ContentWorkItemCompanion data) {
    return ContentWorkItemData(
      workItemId: data.workItemId.present
          ? data.workItemId.value
          : this.workItemId,
      targetNamespace: data.targetNamespace.present
          ? data.targetNamespace.value
          : this.targetNamespace,
      copyId: data.copyId.present ? data.copyId.value : this.copyId,
      kind: data.kind.present ? data.kind.value : this.kind,
      state: data.state.present ? data.state.value : this.state,
      inputManifestId: data.inputManifestId.present
          ? data.inputManifestId.value
          : this.inputManifestId,
      inputJson: data.inputJson.present ? data.inputJson.value : this.inputJson,
      localArtifactPath: data.localArtifactPath.present
          ? data.localArtifactPath.value
          : this.localArtifactPath,
      remoteDestination: data.remoteDestination.present
          ? data.remoteDestination.value
          : this.remoteDestination,
      artifactsJson: data.artifactsJson.present
          ? data.artifactsJson.value
          : this.artifactsJson,
      committedObjectsJson: data.committedObjectsJson.present
          ? data.committedObjectsJson.value
          : this.committedObjectsJson,
      pendingManifestId: data.pendingManifestId.present
          ? data.pendingManifestId.value
          : this.pendingManifestId,
      source: data.source.present ? data.source.value : this.source,
      finishAction: data.finishAction.present
          ? data.finishAction.value
          : this.finishAction,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentWorkItemData(')
          ..write('workItemId: $workItemId, ')
          ..write('targetNamespace: $targetNamespace, ')
          ..write('copyId: $copyId, ')
          ..write('kind: $kind, ')
          ..write('state: $state, ')
          ..write('inputManifestId: $inputManifestId, ')
          ..write('inputJson: $inputJson, ')
          ..write('localArtifactPath: $localArtifactPath, ')
          ..write('remoteDestination: $remoteDestination, ')
          ..write('artifactsJson: $artifactsJson, ')
          ..write('committedObjectsJson: $committedObjectsJson, ')
          ..write('pendingManifestId: $pendingManifestId, ')
          ..write('source: $source, ')
          ..write('finishAction: $finishAction, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    workItemId,
    targetNamespace,
    copyId,
    kind,
    state,
    inputManifestId,
    inputJson,
    localArtifactPath,
    remoteDestination,
    artifactsJson,
    committedObjectsJson,
    pendingManifestId,
    source,
    finishAction,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentWorkItemData &&
          other.workItemId == this.workItemId &&
          other.targetNamespace == this.targetNamespace &&
          other.copyId == this.copyId &&
          other.kind == this.kind &&
          other.state == this.state &&
          other.inputManifestId == this.inputManifestId &&
          other.inputJson == this.inputJson &&
          other.localArtifactPath == this.localArtifactPath &&
          other.remoteDestination == this.remoteDestination &&
          other.artifactsJson == this.artifactsJson &&
          other.committedObjectsJson == this.committedObjectsJson &&
          other.pendingManifestId == this.pendingManifestId &&
          other.source == this.source &&
          other.finishAction == this.finishAction &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ContentWorkItemCompanion extends UpdateCompanion<ContentWorkItemData> {
  final Value<String> workItemId;
  final Value<String> targetNamespace;
  final Value<String?> copyId;
  final Value<String> kind;
  final Value<String> state;
  final Value<String?> inputManifestId;
  final Value<String> inputJson;
  final Value<String?> localArtifactPath;
  final Value<String?> remoteDestination;
  final Value<String> artifactsJson;
  final Value<String> committedObjectsJson;
  final Value<String?> pendingManifestId;
  final Value<String> source;
  final Value<String> finishAction;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const ContentWorkItemCompanion({
    this.workItemId = const Value.absent(),
    this.targetNamespace = const Value.absent(),
    this.copyId = const Value.absent(),
    this.kind = const Value.absent(),
    this.state = const Value.absent(),
    this.inputManifestId = const Value.absent(),
    this.inputJson = const Value.absent(),
    this.localArtifactPath = const Value.absent(),
    this.remoteDestination = const Value.absent(),
    this.artifactsJson = const Value.absent(),
    this.committedObjectsJson = const Value.absent(),
    this.pendingManifestId = const Value.absent(),
    this.source = const Value.absent(),
    this.finishAction = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentWorkItemCompanion.insert({
    required String workItemId,
    required String targetNamespace,
    this.copyId = const Value.absent(),
    required String kind,
    required String state,
    this.inputManifestId = const Value.absent(),
    required String inputJson,
    this.localArtifactPath = const Value.absent(),
    this.remoteDestination = const Value.absent(),
    this.artifactsJson = const Value.absent(),
    this.committedObjectsJson = const Value.absent(),
    this.pendingManifestId = const Value.absent(),
    this.source = const Value.absent(),
    this.finishAction = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : workItemId = Value(workItemId),
       targetNamespace = Value(targetNamespace),
       kind = Value(kind),
       state = Value(state),
       inputJson = Value(inputJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ContentWorkItemData> custom({
    Expression<String>? workItemId,
    Expression<String>? targetNamespace,
    Expression<String>? copyId,
    Expression<String>? kind,
    Expression<String>? state,
    Expression<String>? inputManifestId,
    Expression<String>? inputJson,
    Expression<String>? localArtifactPath,
    Expression<String>? remoteDestination,
    Expression<String>? artifactsJson,
    Expression<String>? committedObjectsJson,
    Expression<String>? pendingManifestId,
    Expression<String>? source,
    Expression<String>? finishAction,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (workItemId != null) 'work_item_id': workItemId,
      if (targetNamespace != null) 'target_namespace': targetNamespace,
      if (copyId != null) 'copy_id': copyId,
      if (kind != null) 'kind': kind,
      if (state != null) 'state': state,
      if (inputManifestId != null) 'input_manifest_id': inputManifestId,
      if (inputJson != null) 'input_json': inputJson,
      if (localArtifactPath != null) 'local_artifact_path': localArtifactPath,
      if (remoteDestination != null) 'remote_destination': remoteDestination,
      if (artifactsJson != null) 'artifacts_json': artifactsJson,
      if (committedObjectsJson != null)
        'committed_objects_json': committedObjectsJson,
      if (pendingManifestId != null) 'pending_manifest_id': pendingManifestId,
      if (source != null) 'source': source,
      if (finishAction != null) 'finish_action': finishAction,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentWorkItemCompanion copyWith({
    Value<String>? workItemId,
    Value<String>? targetNamespace,
    Value<String?>? copyId,
    Value<String>? kind,
    Value<String>? state,
    Value<String?>? inputManifestId,
    Value<String>? inputJson,
    Value<String?>? localArtifactPath,
    Value<String?>? remoteDestination,
    Value<String>? artifactsJson,
    Value<String>? committedObjectsJson,
    Value<String?>? pendingManifestId,
    Value<String>? source,
    Value<String>? finishAction,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return ContentWorkItemCompanion(
      workItemId: workItemId ?? this.workItemId,
      targetNamespace: targetNamespace ?? this.targetNamespace,
      copyId: copyId ?? this.copyId,
      kind: kind ?? this.kind,
      state: state ?? this.state,
      inputManifestId: inputManifestId ?? this.inputManifestId,
      inputJson: inputJson ?? this.inputJson,
      localArtifactPath: localArtifactPath ?? this.localArtifactPath,
      remoteDestination: remoteDestination ?? this.remoteDestination,
      artifactsJson: artifactsJson ?? this.artifactsJson,
      committedObjectsJson: committedObjectsJson ?? this.committedObjectsJson,
      pendingManifestId: pendingManifestId ?? this.pendingManifestId,
      source: source ?? this.source,
      finishAction: finishAction ?? this.finishAction,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (workItemId.present) {
      map['work_item_id'] = Variable<String>(workItemId.value);
    }
    if (targetNamespace.present) {
      map['target_namespace'] = Variable<String>(targetNamespace.value);
    }
    if (copyId.present) {
      map['copy_id'] = Variable<String>(copyId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (inputManifestId.present) {
      map['input_manifest_id'] = Variable<String>(inputManifestId.value);
    }
    if (inputJson.present) {
      map['input_json'] = Variable<String>(inputJson.value);
    }
    if (localArtifactPath.present) {
      map['local_artifact_path'] = Variable<String>(localArtifactPath.value);
    }
    if (remoteDestination.present) {
      map['remote_destination'] = Variable<String>(remoteDestination.value);
    }
    if (artifactsJson.present) {
      map['artifacts_json'] = Variable<String>(artifactsJson.value);
    }
    if (committedObjectsJson.present) {
      map['committed_objects_json'] = Variable<String>(
        committedObjectsJson.value,
      );
    }
    if (pendingManifestId.present) {
      map['pending_manifest_id'] = Variable<String>(pendingManifestId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (finishAction.present) {
      map['finish_action'] = Variable<String>(finishAction.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentWorkItemCompanion(')
          ..write('workItemId: $workItemId, ')
          ..write('targetNamespace: $targetNamespace, ')
          ..write('copyId: $copyId, ')
          ..write('kind: $kind, ')
          ..write('state: $state, ')
          ..write('inputManifestId: $inputManifestId, ')
          ..write('inputJson: $inputJson, ')
          ..write('localArtifactPath: $localArtifactPath, ')
          ..write('remoteDestination: $remoteDestination, ')
          ..write('artifactsJson: $artifactsJson, ')
          ..write('committedObjectsJson: $committedObjectsJson, ')
          ..write('pendingManifestId: $pendingManifestId, ')
          ..write('source: $source, ')
          ..write('finishAction: $finishAction, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentPageReplacementTable extends ContentPageReplacement
    with TableInfo<$ContentPageReplacementTable, ContentPageReplacementData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentPageReplacementTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _replacementIdMeta = const VerificationMeta(
    'replacementId',
  );
  @override
  late final GeneratedColumn<String> replacementId = GeneratedColumn<String>(
    'replacement_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _copyIdMeta = const VerificationMeta('copyId');
  @override
  late final GeneratedColumn<String> copyId = GeneratedColumn<String>(
    'copy_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queueOrderMeta = const VerificationMeta(
    'queueOrder',
  );
  @override
  late final GeneratedColumn<int> queueOrder = GeneratedColumn<int>(
    'queue_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _oldPathMeta = const VerificationMeta(
    'oldPath',
  );
  @override
  late final GeneratedColumn<String> oldPath = GeneratedColumn<String>(
    'old_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _newPathMeta = const VerificationMeta(
    'newPath',
  );
  @override
  late final GeneratedColumn<String> newPath = GeneratedColumn<String>(
    'new_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tempPathMeta = const VerificationMeta(
    'tempPath',
  );
  @override
  late final GeneratedColumn<String> tempPath = GeneratedColumn<String>(
    'temp_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retainedPathMeta = const VerificationMeta(
    'retainedPath',
  );
  @override
  late final GeneratedColumn<String> retainedPath = GeneratedColumn<String>(
    'retained_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _newMetadataJsonMeta = const VerificationMeta(
    'newMetadataJson',
  );
  @override
  late final GeneratedColumn<String> newMetadataJson = GeneratedColumn<String>(
    'new_metadata_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    replacementId,
    copyId,
    ordinal,
    queueOrder,
    state,
    oldPath,
    newPath,
    tempPath,
    retainedPath,
    newMetadataJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_page_replacement';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentPageReplacementData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('replacement_id')) {
      context.handle(
        _replacementIdMeta,
        replacementId.isAcceptableOrUnknown(
          data['replacement_id']!,
          _replacementIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_replacementIdMeta);
    }
    if (data.containsKey('copy_id')) {
      context.handle(
        _copyIdMeta,
        copyId.isAcceptableOrUnknown(data['copy_id']!, _copyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_copyIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('queue_order')) {
      context.handle(
        _queueOrderMeta,
        queueOrder.isAcceptableOrUnknown(data['queue_order']!, _queueOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_queueOrderMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('old_path')) {
      context.handle(
        _oldPathMeta,
        oldPath.isAcceptableOrUnknown(data['old_path']!, _oldPathMeta),
      );
    } else if (isInserting) {
      context.missing(_oldPathMeta);
    }
    if (data.containsKey('new_path')) {
      context.handle(
        _newPathMeta,
        newPath.isAcceptableOrUnknown(data['new_path']!, _newPathMeta),
      );
    } else if (isInserting) {
      context.missing(_newPathMeta);
    }
    if (data.containsKey('temp_path')) {
      context.handle(
        _tempPathMeta,
        tempPath.isAcceptableOrUnknown(data['temp_path']!, _tempPathMeta),
      );
    } else if (isInserting) {
      context.missing(_tempPathMeta);
    }
    if (data.containsKey('retained_path')) {
      context.handle(
        _retainedPathMeta,
        retainedPath.isAcceptableOrUnknown(
          data['retained_path']!,
          _retainedPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_retainedPathMeta);
    }
    if (data.containsKey('new_metadata_json')) {
      context.handle(
        _newMetadataJsonMeta,
        newMetadataJson.isAcceptableOrUnknown(
          data['new_metadata_json']!,
          _newMetadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {replacementId};
  @override
  ContentPageReplacementData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentPageReplacementData(
      replacementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}replacement_id'],
      )!,
      copyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}copy_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      queueOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}queue_order'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      oldPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_path'],
      )!,
      newPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_path'],
      )!,
      tempPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}temp_path'],
      )!,
      retainedPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}retained_path'],
      )!,
      newMetadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_metadata_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ContentPageReplacementTable createAlias(String alias) {
    return $ContentPageReplacementTable(attachedDatabase, alias);
  }
}

class ContentPageReplacementData extends DataClass
    implements Insertable<ContentPageReplacementData> {
  final String replacementId;
  final String copyId;
  final int ordinal;
  final int queueOrder;
  final String state;
  final String oldPath;
  final String newPath;
  final String tempPath;
  final String retainedPath;
  final String? newMetadataJson;
  final String createdAt;
  const ContentPageReplacementData({
    required this.replacementId,
    required this.copyId,
    required this.ordinal,
    required this.queueOrder,
    required this.state,
    required this.oldPath,
    required this.newPath,
    required this.tempPath,
    required this.retainedPath,
    this.newMetadataJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['replacement_id'] = Variable<String>(replacementId);
    map['copy_id'] = Variable<String>(copyId);
    map['ordinal'] = Variable<int>(ordinal);
    map['queue_order'] = Variable<int>(queueOrder);
    map['state'] = Variable<String>(state);
    map['old_path'] = Variable<String>(oldPath);
    map['new_path'] = Variable<String>(newPath);
    map['temp_path'] = Variable<String>(tempPath);
    map['retained_path'] = Variable<String>(retainedPath);
    if (!nullToAbsent || newMetadataJson != null) {
      map['new_metadata_json'] = Variable<String>(newMetadataJson);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  ContentPageReplacementCompanion toCompanion(bool nullToAbsent) {
    return ContentPageReplacementCompanion(
      replacementId: Value(replacementId),
      copyId: Value(copyId),
      ordinal: Value(ordinal),
      queueOrder: Value(queueOrder),
      state: Value(state),
      oldPath: Value(oldPath),
      newPath: Value(newPath),
      tempPath: Value(tempPath),
      retainedPath: Value(retainedPath),
      newMetadataJson: newMetadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(newMetadataJson),
      createdAt: Value(createdAt),
    );
  }

  factory ContentPageReplacementData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentPageReplacementData(
      replacementId: serializer.fromJson<String>(json['replacementId']),
      copyId: serializer.fromJson<String>(json['copyId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      queueOrder: serializer.fromJson<int>(json['queueOrder']),
      state: serializer.fromJson<String>(json['state']),
      oldPath: serializer.fromJson<String>(json['oldPath']),
      newPath: serializer.fromJson<String>(json['newPath']),
      tempPath: serializer.fromJson<String>(json['tempPath']),
      retainedPath: serializer.fromJson<String>(json['retainedPath']),
      newMetadataJson: serializer.fromJson<String?>(json['newMetadataJson']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'replacementId': serializer.toJson<String>(replacementId),
      'copyId': serializer.toJson<String>(copyId),
      'ordinal': serializer.toJson<int>(ordinal),
      'queueOrder': serializer.toJson<int>(queueOrder),
      'state': serializer.toJson<String>(state),
      'oldPath': serializer.toJson<String>(oldPath),
      'newPath': serializer.toJson<String>(newPath),
      'tempPath': serializer.toJson<String>(tempPath),
      'retainedPath': serializer.toJson<String>(retainedPath),
      'newMetadataJson': serializer.toJson<String?>(newMetadataJson),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  ContentPageReplacementData copyWith({
    String? replacementId,
    String? copyId,
    int? ordinal,
    int? queueOrder,
    String? state,
    String? oldPath,
    String? newPath,
    String? tempPath,
    String? retainedPath,
    Value<String?> newMetadataJson = const Value.absent(),
    String? createdAt,
  }) => ContentPageReplacementData(
    replacementId: replacementId ?? this.replacementId,
    copyId: copyId ?? this.copyId,
    ordinal: ordinal ?? this.ordinal,
    queueOrder: queueOrder ?? this.queueOrder,
    state: state ?? this.state,
    oldPath: oldPath ?? this.oldPath,
    newPath: newPath ?? this.newPath,
    tempPath: tempPath ?? this.tempPath,
    retainedPath: retainedPath ?? this.retainedPath,
    newMetadataJson: newMetadataJson.present
        ? newMetadataJson.value
        : this.newMetadataJson,
    createdAt: createdAt ?? this.createdAt,
  );
  ContentPageReplacementData copyWithCompanion(
    ContentPageReplacementCompanion data,
  ) {
    return ContentPageReplacementData(
      replacementId: data.replacementId.present
          ? data.replacementId.value
          : this.replacementId,
      copyId: data.copyId.present ? data.copyId.value : this.copyId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      queueOrder: data.queueOrder.present
          ? data.queueOrder.value
          : this.queueOrder,
      state: data.state.present ? data.state.value : this.state,
      oldPath: data.oldPath.present ? data.oldPath.value : this.oldPath,
      newPath: data.newPath.present ? data.newPath.value : this.newPath,
      tempPath: data.tempPath.present ? data.tempPath.value : this.tempPath,
      retainedPath: data.retainedPath.present
          ? data.retainedPath.value
          : this.retainedPath,
      newMetadataJson: data.newMetadataJson.present
          ? data.newMetadataJson.value
          : this.newMetadataJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentPageReplacementData(')
          ..write('replacementId: $replacementId, ')
          ..write('copyId: $copyId, ')
          ..write('ordinal: $ordinal, ')
          ..write('queueOrder: $queueOrder, ')
          ..write('state: $state, ')
          ..write('oldPath: $oldPath, ')
          ..write('newPath: $newPath, ')
          ..write('tempPath: $tempPath, ')
          ..write('retainedPath: $retainedPath, ')
          ..write('newMetadataJson: $newMetadataJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    replacementId,
    copyId,
    ordinal,
    queueOrder,
    state,
    oldPath,
    newPath,
    tempPath,
    retainedPath,
    newMetadataJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentPageReplacementData &&
          other.replacementId == this.replacementId &&
          other.copyId == this.copyId &&
          other.ordinal == this.ordinal &&
          other.queueOrder == this.queueOrder &&
          other.state == this.state &&
          other.oldPath == this.oldPath &&
          other.newPath == this.newPath &&
          other.tempPath == this.tempPath &&
          other.retainedPath == this.retainedPath &&
          other.newMetadataJson == this.newMetadataJson &&
          other.createdAt == this.createdAt);
}

class ContentPageReplacementCompanion
    extends UpdateCompanion<ContentPageReplacementData> {
  final Value<String> replacementId;
  final Value<String> copyId;
  final Value<int> ordinal;
  final Value<int> queueOrder;
  final Value<String> state;
  final Value<String> oldPath;
  final Value<String> newPath;
  final Value<String> tempPath;
  final Value<String> retainedPath;
  final Value<String?> newMetadataJson;
  final Value<String> createdAt;
  final Value<int> rowid;
  const ContentPageReplacementCompanion({
    this.replacementId = const Value.absent(),
    this.copyId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.queueOrder = const Value.absent(),
    this.state = const Value.absent(),
    this.oldPath = const Value.absent(),
    this.newPath = const Value.absent(),
    this.tempPath = const Value.absent(),
    this.retainedPath = const Value.absent(),
    this.newMetadataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentPageReplacementCompanion.insert({
    required String replacementId,
    required String copyId,
    required int ordinal,
    required int queueOrder,
    required String state,
    required String oldPath,
    required String newPath,
    required String tempPath,
    required String retainedPath,
    this.newMetadataJson = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : replacementId = Value(replacementId),
       copyId = Value(copyId),
       ordinal = Value(ordinal),
       queueOrder = Value(queueOrder),
       state = Value(state),
       oldPath = Value(oldPath),
       newPath = Value(newPath),
       tempPath = Value(tempPath),
       retainedPath = Value(retainedPath),
       createdAt = Value(createdAt);
  static Insertable<ContentPageReplacementData> custom({
    Expression<String>? replacementId,
    Expression<String>? copyId,
    Expression<int>? ordinal,
    Expression<int>? queueOrder,
    Expression<String>? state,
    Expression<String>? oldPath,
    Expression<String>? newPath,
    Expression<String>? tempPath,
    Expression<String>? retainedPath,
    Expression<String>? newMetadataJson,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (replacementId != null) 'replacement_id': replacementId,
      if (copyId != null) 'copy_id': copyId,
      if (ordinal != null) 'ordinal': ordinal,
      if (queueOrder != null) 'queue_order': queueOrder,
      if (state != null) 'state': state,
      if (oldPath != null) 'old_path': oldPath,
      if (newPath != null) 'new_path': newPath,
      if (tempPath != null) 'temp_path': tempPath,
      if (retainedPath != null) 'retained_path': retainedPath,
      if (newMetadataJson != null) 'new_metadata_json': newMetadataJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentPageReplacementCompanion copyWith({
    Value<String>? replacementId,
    Value<String>? copyId,
    Value<int>? ordinal,
    Value<int>? queueOrder,
    Value<String>? state,
    Value<String>? oldPath,
    Value<String>? newPath,
    Value<String>? tempPath,
    Value<String>? retainedPath,
    Value<String?>? newMetadataJson,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return ContentPageReplacementCompanion(
      replacementId: replacementId ?? this.replacementId,
      copyId: copyId ?? this.copyId,
      ordinal: ordinal ?? this.ordinal,
      queueOrder: queueOrder ?? this.queueOrder,
      state: state ?? this.state,
      oldPath: oldPath ?? this.oldPath,
      newPath: newPath ?? this.newPath,
      tempPath: tempPath ?? this.tempPath,
      retainedPath: retainedPath ?? this.retainedPath,
      newMetadataJson: newMetadataJson ?? this.newMetadataJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (replacementId.present) {
      map['replacement_id'] = Variable<String>(replacementId.value);
    }
    if (copyId.present) {
      map['copy_id'] = Variable<String>(copyId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (queueOrder.present) {
      map['queue_order'] = Variable<int>(queueOrder.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (oldPath.present) {
      map['old_path'] = Variable<String>(oldPath.value);
    }
    if (newPath.present) {
      map['new_path'] = Variable<String>(newPath.value);
    }
    if (tempPath.present) {
      map['temp_path'] = Variable<String>(tempPath.value);
    }
    if (retainedPath.present) {
      map['retained_path'] = Variable<String>(retainedPath.value);
    }
    if (newMetadataJson.present) {
      map['new_metadata_json'] = Variable<String>(newMetadataJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentPageReplacementCompanion(')
          ..write('replacementId: $replacementId, ')
          ..write('copyId: $copyId, ')
          ..write('ordinal: $ordinal, ')
          ..write('queueOrder: $queueOrder, ')
          ..write('state: $state, ')
          ..write('oldPath: $oldPath, ')
          ..write('newPath: $newPath, ')
          ..write('tempPath: $tempPath, ')
          ..write('retainedPath: $retainedPath, ')
          ..write('newMetadataJson: $newMetadataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $TagTable tag = $TagTable(this);
  late final $ContentCopyTable contentCopy = $ContentCopyTable(this);
  late final $ArchiveDownloadedTable archiveDownloaded =
      $ArchiveDownloadedTable(this);
  late final $ArchiveGroupTable archiveGroup = $ArchiveGroupTable(this);
  late final $GalleryDownloadedTable galleryDownloaded =
      $GalleryDownloadedTable(this);
  late final $GalleryGroupTable galleryGroup = $GalleryGroupTable(this);
  late final $ImageTable image = $ImageTable(this);
  late final $GalleryHistoryV2Table galleryHistoryV2 = $GalleryHistoryV2Table(
    this,
  );
  late final $TagCountTable tagCount = $TagCountTable(this);
  late final $DioCacheTable dioCache = $DioCacheTable(this);
  late final $BlockRuleTable blockRule = $BlockRuleTable(this);
  late final $LocalConfigTable localConfig = $LocalConfigTable(this);
  late final $ContentPageTable contentPage = $ContentPageTable(this);
  late final $ContentRemoteResourceTable contentRemoteResource =
      $ContentRemoteResourceTable(this);
  late final $ContentRemotePartitionTable contentRemotePartition =
      $ContentRemotePartitionTable(this);
  late final $ContentManifestTable contentManifest = $ContentManifestTable(
    this,
  );
  late final $ContentObjectRepresentationTable contentObjectRepresentation =
      $ContentObjectRepresentationTable(this);
  late final $ContentWorkItemTable contentWorkItem = $ContentWorkItemTable(
    this,
  );
  late final $ContentPageReplacementTable contentPageReplacement =
      $ContentPageReplacementTable(this);
  late final Index idxKey = Index(
    'idx_key',
    'CREATE INDEX idx_key ON tag (_key)',
  );
  late final Index idxTagName = Index(
    'idx_tagName',
    'CREATE INDEX idx_tagName ON tag (tagName)',
  );
  late final Index aIdxInsertTime = Index(
    'a_idx_insert_time',
    'CREATE INDEX a_idx_insert_time ON archive_downloaded_v2 (insert_time)',
  );
  late final Index aIdxSortOrder = Index(
    'a_idx_sort_order',
    'CREATE INDEX a_idx_sort_order ON archive_downloaded_v2 (sort_order)',
  );
  late final Index aIdxGroupName = Index(
    'a_idx_group_name',
    'CREATE INDEX a_idx_group_name ON archive_downloaded_v2 (group_name)',
  );
  late final Index aIdxTagRefreshTime = Index(
    'a_idx_tag_refresh_time',
    'CREATE INDEX a_idx_tag_refresh_time ON archive_downloaded_v2 (tag_refresh_time)',
  );
  late final Index gIdxInsertTime = Index(
    'g_idx_insert_time',
    'CREATE INDEX g_idx_insert_time ON gallery_downloaded_v2 (insert_time)',
  );
  late final Index gIdxSortOrder = Index(
    'g_idx_sort_order',
    'CREATE INDEX g_idx_sort_order ON gallery_downloaded_v2 (sort_order)',
  );
  late final Index gIdxGroupName = Index(
    'g_idx_group_name',
    'CREATE INDEX g_idx_group_name ON gallery_downloaded_v2 (group_name)',
  );
  late final Index gIdxTagRefreshTime = Index(
    'g_idx_tag_refresh_time',
    'CREATE INDEX g_idx_tag_refresh_time ON gallery_downloaded_v2 (tag_refresh_time)',
  );
  late final Index idxGh2LastReadTime = Index(
    'idx_gh2_last_read_time',
    'CREATE INDEX idx_gh2_last_read_time ON gallery_history_v2 (lastReadTime)',
  );
  late final Index idxExpireDate = Index(
    'idx_expire_date',
    'CREATE INDEX idx_expire_date ON dio_cache (expireDate)',
  );
  late final Index idxUrl = Index(
    'idx_url',
    'CREATE INDEX idx_url ON dio_cache (url)',
  );
  late final Index idxGroupId = Index(
    'idx_group_id',
    'CREATE INDEX idx_group_id ON block_rule (group_id)',
  );
  late final Index idxTarget = Index(
    'idx_target',
    'CREATE INDEX idx_target ON block_rule (target)',
  );
  late final Index lIdxUTime = Index(
    'l_idx_u_time',
    'CREATE INDEX l_idx_u_time ON local_config (utime)',
  );
  late final Index contentCopyRootUnique = Index(
    'content_copy_root_unique',
    'CREATE UNIQUE INDEX content_copy_root_unique ON content_copy (root_path)',
  );
  late final Index contentCopyCurrentUnique = Index(
    'content_copy_current_unique',
    'CREATE UNIQUE INDEX content_copy_current_unique ON content_copy (gid, representation) WHERE is_current = 1',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tag,
    contentCopy,
    archiveDownloaded,
    archiveGroup,
    galleryDownloaded,
    galleryGroup,
    image,
    galleryHistoryV2,
    tagCount,
    dioCache,
    blockRule,
    localConfig,
    contentPage,
    contentRemoteResource,
    contentRemotePartition,
    contentManifest,
    contentObjectRepresentation,
    contentWorkItem,
    contentPageReplacement,
    idxKey,
    idxTagName,
    aIdxInsertTime,
    aIdxSortOrder,
    aIdxGroupName,
    aIdxTagRefreshTime,
    gIdxInsertTime,
    gIdxSortOrder,
    gIdxGroupName,
    gIdxTagRefreshTime,
    idxGh2LastReadTime,
    idxExpireDate,
    idxUrl,
    idxGroupId,
    idxTarget,
    lIdxUTime,
    contentCopyRootUnique,
    contentCopyCurrentUnique,
  ];
}

typedef $$TagTableCreateCompanionBuilder = TagCompanion Function({
  required String namespace,
  required String key,
  Value<String?> translatedNamespace,
  Value<String?> tagName,
  Value<String?> fullTagName,
  Value<String?> intro,
  Value<String?> links,
  Value<int> rowid,
});
typedef $$TagTableUpdateCompanionBuilder = TagCompanion Function({
  Value<String> namespace,
  Value<String> key,
  Value<String?> translatedNamespace,
  Value<String?> tagName,
  Value<String?> fullTagName,
  Value<String?> intro,
  Value<String?> links,
  Value<int> rowid,
});

class $$TagTableFilterComposer extends Composer<_$AppDb, $TagTable> {
  $$TagTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get namespace => $composableBuilder(
    column: $table.namespace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translatedNamespace => $composableBuilder(
    column: $table.translatedNamespace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagName => $composableBuilder(
    column: $table.tagName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullTagName => $composableBuilder(
    column: $table.fullTagName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get links => $composableBuilder(
    column: $table.links,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagTableOrderingComposer extends Composer<_$AppDb, $TagTable> {
  $$TagTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get namespace => $composableBuilder(
    column: $table.namespace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translatedNamespace => $composableBuilder(
    column: $table.translatedNamespace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagName => $composableBuilder(
    column: $table.tagName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullTagName => $composableBuilder(
    column: $table.fullTagName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get links => $composableBuilder(
    column: $table.links,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagTableAnnotationComposer extends Composer<_$AppDb, $TagTable> {
  $$TagTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get namespace =>
      $composableBuilder(column: $table.namespace, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get translatedNamespace => $composableBuilder(
    column: $table.translatedNamespace,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagName =>
      $composableBuilder(column: $table.tagName, builder: (column) => column);

  GeneratedColumn<String> get fullTagName => $composableBuilder(
    column: $table.fullTagName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get intro =>
      $composableBuilder(column: $table.intro, builder: (column) => column);

  GeneratedColumn<String> get links =>
      $composableBuilder(column: $table.links, builder: (column) => column);
}

class $$TagTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $TagTable,
          TagData,
          $$TagTableFilterComposer,
          $$TagTableOrderingComposer,
          $$TagTableAnnotationComposer,
          $$TagTableCreateCompanionBuilder,
          $$TagTableUpdateCompanionBuilder,
          (TagData, BaseReferences<_$AppDb, $TagTable, TagData>),
          TagData,
          PrefetchHooks Function()
        > {
  $$TagTableTableManager(_$AppDb db, $TagTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> namespace = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String?> translatedNamespace = const Value.absent(),
                Value<String?> tagName = const Value.absent(),
                Value<String?> fullTagName = const Value.absent(),
                Value<String?> intro = const Value.absent(),
                Value<String?> links = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagCompanion(
                namespace: namespace,
                key: key,
                translatedNamespace: translatedNamespace,
                tagName: tagName,
                fullTagName: fullTagName,
                intro: intro,
                links: links,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String namespace,
                required String key,
                Value<String?> translatedNamespace = const Value.absent(),
                Value<String?> tagName = const Value.absent(),
                Value<String?> fullTagName = const Value.absent(),
                Value<String?> intro = const Value.absent(),
                Value<String?> links = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagCompanion.insert(
                namespace: namespace,
                key: key,
                translatedNamespace: translatedNamespace,
                tagName: tagName,
                fullTagName: fullTagName,
                intro: intro,
                links: links,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagTable, TagData>(table),
                  BaseReferences<_$AppDb, $TagTable, TagData>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $TagTable,
      TagData,
      $$TagTableFilterComposer,
      $$TagTableOrderingComposer,
      $$TagTableAnnotationComposer,
      $$TagTableCreateCompanionBuilder,
      $$TagTableUpdateCompanionBuilder,
      (TagData, BaseReferences<_$AppDb, $TagTable, TagData>),
      TagData,
      PrefetchHooks Function()
    >;
typedef $$ContentCopyTableCreateCompanionBuilder =
    ContentCopyCompanion Function({
      required String copyId,
      required int gid,
      required String representation,
      required String rootPath,
      Value<String?> metadataJson,
      Value<String?> libraryNamespace,
      Value<bool> isCurrent,
      Value<String> lifecycle,
      Value<String?> trashPath,
      Value<String?> cleanupState,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$ContentCopyTableUpdateCompanionBuilder =
    ContentCopyCompanion Function({
      Value<String> copyId,
      Value<int> gid,
      Value<String> representation,
      Value<String> rootPath,
      Value<String?> metadataJson,
      Value<String?> libraryNamespace,
      Value<bool> isCurrent,
      Value<String> lifecycle,
      Value<String?> trashPath,
      Value<String?> cleanupState,
      Value<String> createdAt,
      Value<int> rowid,
    });

final class $$ContentCopyTableReferences
    extends BaseReferences<_$AppDb, $ContentCopyTable, ContentCopyData> {
  $$ContentCopyTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $ArchiveDownloadedTable,
    List<ArchiveDownloadedData>
  >
  _archiveDownloadedRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.archiveDownloaded,
    aliasName: 'content_copy__copy_id__archive_downloaded_v2__copy_id',
  );

  $$ArchiveDownloadedTableProcessedTableManager get archiveDownloadedRefs {
    final manager =
        $$ArchiveDownloadedTableTableManager(
          $_db,
          $_db.archiveDownloaded,
        ).filter(
          (f) => f.copyId.copyId.sqlEquals($_itemColumn<String>('copy_id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _archiveDownloadedRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $GalleryDownloadedTable,
    List<GalleryDownloadedData>
  >
  _galleryDownloadedRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.galleryDownloaded,
    aliasName: 'content_copy__copy_id__gallery_downloaded_v2__copy_id',
  );

  $$GalleryDownloadedTableProcessedTableManager get galleryDownloadedRefs {
    final manager =
        $$GalleryDownloadedTableTableManager(
          $_db,
          $_db.galleryDownloaded,
        ).filter(
          (f) => f.copyId.copyId.sqlEquals($_itemColumn<String>('copy_id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _galleryDownloadedRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ContentCopyTableFilterComposer
    extends Composer<_$AppDb, $ContentCopyTable> {
  $$ContentCopyTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get copyId => $composableBuilder(
    column: $table.copyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gid => $composableBuilder(
    column: $table.gid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get representation => $composableBuilder(
    column: $table.representation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootPath => $composableBuilder(
    column: $table.rootPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get libraryNamespace => $composableBuilder(
    column: $table.libraryNamespace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCurrent => $composableBuilder(
    column: $table.isCurrent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trashPath => $composableBuilder(
    column: $table.trashPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cleanupState => $composableBuilder(
    column: $table.cleanupState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> archiveDownloadedRefs(
    Expression<bool> Function($$ArchiveDownloadedTableFilterComposer f) f,
  ) {
    final $$ArchiveDownloadedTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.copyId,
      referencedTable: $db.archiveDownloaded,
      getReferencedColumn: (t) => t.copyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArchiveDownloadedTableFilterComposer(
            $db: $db,
            $table: $db.archiveDownloaded,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> galleryDownloadedRefs(
    Expression<bool> Function($$GalleryDownloadedTableFilterComposer f) f,
  ) {
    final $$GalleryDownloadedTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.copyId,
      referencedTable: $db.galleryDownloaded,
      getReferencedColumn: (t) => t.copyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryDownloadedTableFilterComposer(
            $db: $db,
            $table: $db.galleryDownloaded,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ContentCopyTableOrderingComposer
    extends Composer<_$AppDb, $ContentCopyTable> {
  $$ContentCopyTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get copyId => $composableBuilder(
    column: $table.copyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gid => $composableBuilder(
    column: $table.gid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get representation => $composableBuilder(
    column: $table.representation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootPath => $composableBuilder(
    column: $table.rootPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get libraryNamespace => $composableBuilder(
    column: $table.libraryNamespace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCurrent => $composableBuilder(
    column: $table.isCurrent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trashPath => $composableBuilder(
    column: $table.trashPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cleanupState => $composableBuilder(
    column: $table.cleanupState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentCopyTableAnnotationComposer
    extends Composer<_$AppDb, $ContentCopyTable> {
  $$ContentCopyTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get copyId =>
      $composableBuilder(column: $table.copyId, builder: (column) => column);

  GeneratedColumn<int> get gid =>
      $composableBuilder(column: $table.gid, builder: (column) => column);

  GeneratedColumn<String> get representation => $composableBuilder(
    column: $table.representation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rootPath =>
      $composableBuilder(column: $table.rootPath, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get libraryNamespace => $composableBuilder(
    column: $table.libraryNamespace,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCurrent =>
      $composableBuilder(column: $table.isCurrent, builder: (column) => column);

  GeneratedColumn<String> get lifecycle =>
      $composableBuilder(column: $table.lifecycle, builder: (column) => column);

  GeneratedColumn<String> get trashPath =>
      $composableBuilder(column: $table.trashPath, builder: (column) => column);

  GeneratedColumn<String> get cleanupState => $composableBuilder(
    column: $table.cleanupState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> archiveDownloadedRefs<T extends Object>(
    Expression<T> Function($$ArchiveDownloadedTableAnnotationComposer a) f,
  ) {
    final $$ArchiveDownloadedTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.copyId,
          referencedTable: $db.archiveDownloaded,
          getReferencedColumn: (t) => t.copyId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ArchiveDownloadedTableAnnotationComposer(
                $db: $db,
                $table: $db.archiveDownloaded,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> galleryDownloadedRefs<T extends Object>(
    Expression<T> Function($$GalleryDownloadedTableAnnotationComposer a) f,
  ) {
    final $$GalleryDownloadedTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.copyId,
          referencedTable: $db.galleryDownloaded,
          getReferencedColumn: (t) => t.copyId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GalleryDownloadedTableAnnotationComposer(
                $db: $db,
                $table: $db.galleryDownloaded,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ContentCopyTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ContentCopyTable,
          ContentCopyData,
          $$ContentCopyTableFilterComposer,
          $$ContentCopyTableOrderingComposer,
          $$ContentCopyTableAnnotationComposer,
          $$ContentCopyTableCreateCompanionBuilder,
          $$ContentCopyTableUpdateCompanionBuilder,
          (ContentCopyData, $$ContentCopyTableReferences),
          ContentCopyData,
          PrefetchHooks Function({
            bool archiveDownloadedRefs,
            bool galleryDownloadedRefs,
          })
        > {
  $$ContentCopyTableTableManager(_$AppDb db, $ContentCopyTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentCopyTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentCopyTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentCopyTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> copyId = const Value.absent(),
                Value<int> gid = const Value.absent(),
                Value<String> representation = const Value.absent(),
                Value<String> rootPath = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<String?> libraryNamespace = const Value.absent(),
                Value<bool> isCurrent = const Value.absent(),
                Value<String> lifecycle = const Value.absent(),
                Value<String?> trashPath = const Value.absent(),
                Value<String?> cleanupState = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentCopyCompanion(
                copyId: copyId,
                gid: gid,
                representation: representation,
                rootPath: rootPath,
                metadataJson: metadataJson,
                libraryNamespace: libraryNamespace,
                isCurrent: isCurrent,
                lifecycle: lifecycle,
                trashPath: trashPath,
                cleanupState: cleanupState,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String copyId,
                required int gid,
                required String representation,
                required String rootPath,
                Value<String?> metadataJson = const Value.absent(),
                Value<String?> libraryNamespace = const Value.absent(),
                Value<bool> isCurrent = const Value.absent(),
                Value<String> lifecycle = const Value.absent(),
                Value<String?> trashPath = const Value.absent(),
                Value<String?> cleanupState = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ContentCopyCompanion.insert(
                copyId: copyId,
                gid: gid,
                representation: representation,
                rootPath: rootPath,
                metadataJson: metadataJson,
                libraryNamespace: libraryNamespace,
                isCurrent: isCurrent,
                lifecycle: lifecycle,
                trashPath: trashPath,
                cleanupState: cleanupState,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContentCopyTable, ContentCopyData>(table),
                  $$ContentCopyTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({archiveDownloadedRefs = false, galleryDownloadedRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (archiveDownloadedRefs) db.archiveDownloaded,
                    if (galleryDownloadedRefs) db.galleryDownloaded,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (archiveDownloadedRefs)
                        await $_getPrefetchedDataByColumns<
                          ContentCopyData,
                          $ContentCopyTable,
                          ArchiveDownloadedData,
                          $ArchiveDownloadedTable
                        >(
                          currentTable: table,
                          referencedTable: $$ContentCopyTableReferences
                              ._archiveDownloadedRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ContentCopyTableReferences(
                                db,
                                table,
                                p0,
                              ).archiveDownloadedRefs,
                          currentColumn: 'copy_id',
                          referencedColumn: 'copy_id',
                          typedResults: items,
                        ),
                      if (galleryDownloadedRefs)
                        await $_getPrefetchedDataByColumns<
                          ContentCopyData,
                          $ContentCopyTable,
                          GalleryDownloadedData,
                          $GalleryDownloadedTable
                        >(
                          currentTable: table,
                          referencedTable: $$ContentCopyTableReferences
                              ._galleryDownloadedRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ContentCopyTableReferences(
                                db,
                                table,
                                p0,
                              ).galleryDownloadedRefs,
                          currentColumn: 'copy_id',
                          referencedColumn: 'copy_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ContentCopyTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ContentCopyTable,
      ContentCopyData,
      $$ContentCopyTableFilterComposer,
      $$ContentCopyTableOrderingComposer,
      $$ContentCopyTableAnnotationComposer,
      $$ContentCopyTableCreateCompanionBuilder,
      $$ContentCopyTableUpdateCompanionBuilder,
      (ContentCopyData, $$ContentCopyTableReferences),
      ContentCopyData,
      PrefetchHooks Function({
        bool archiveDownloadedRefs,
        bool galleryDownloadedRefs,
      })
    >;
typedef $$ArchiveDownloadedTableCreateCompanionBuilder =
    ArchiveDownloadedCompanion Function({
      Value<int> gid,
      Value<String?> copyId,
      required String token,
      required String title,
      required String category,
      required int pageCount,
      required String galleryUrl,
      required String coverUrl,
      Value<String?> uploader,
      required int size,
      required String publishTime,
      required int archiveStatusCode,
      required String archivePageUrl,
      Value<String?> downloadPageUrl,
      Value<String?> downloadUrl,
      required bool isOriginal,
      required String insertTime,
      Value<int> sortOrder,
      required String groupName,
      Value<String> tags,
      Value<String?> tagRefreshTime,
      Value<int> parseSource,
      Value<String?> sanitizedTitle,
    });
typedef $$ArchiveDownloadedTableUpdateCompanionBuilder =
    ArchiveDownloadedCompanion Function({
      Value<int> gid,
      Value<String?> copyId,
      Value<String> token,
      Value<String> title,
      Value<String> category,
      Value<int> pageCount,
      Value<String> galleryUrl,
      Value<String> coverUrl,
      Value<String?> uploader,
      Value<int> size,
      Value<String> publishTime,
      Value<int> archiveStatusCode,
      Value<String> archivePageUrl,
      Value<String?> downloadPageUrl,
      Value<String?> downloadUrl,
      Value<bool> isOriginal,
      Value<String> insertTime,
      Value<int> sortOrder,
      Value<String> groupName,
      Value<String> tags,
      Value<String?> tagRefreshTime,
      Value<int> parseSource,
      Value<String?> sanitizedTitle,
    });

final class $$ArchiveDownloadedTableReferences
    extends
        BaseReferences<
          _$AppDb,
          $ArchiveDownloadedTable,
          ArchiveDownloadedData
        > {
  $$ArchiveDownloadedTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ContentCopyTable _copyIdTable(_$AppDb db) => db.contentCopy
      .createAlias('archive_downloaded_v2__copy_id__content_copy__copy_id');

  $$ContentCopyTableProcessedTableManager? get copyId {
    final $_column = $_itemColumn<String>('copy_id');
    if ($_column == null) return null;
    final manager = $$ContentCopyTableTableManager(
      $_db,
      $_db.contentCopy,
    ).filter((f) => f.copyId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_copyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ArchiveDownloadedTableFilterComposer
    extends Composer<_$AppDb, $ArchiveDownloadedTable> {
  $$ArchiveDownloadedTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get gid => $composableBuilder(
    column: $table.gid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get token => $composableBuilder(
    column: $table.token,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get galleryUrl => $composableBuilder(
    column: $table.galleryUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploader => $composableBuilder(
    column: $table.uploader,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publishTime => $composableBuilder(
    column: $table.publishTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archiveStatusCode => $composableBuilder(
    column: $table.archiveStatusCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archivePageUrl => $composableBuilder(
    column: $table.archivePageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get downloadPageUrl => $composableBuilder(
    column: $table.downloadPageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOriginal => $composableBuilder(
    column: $table.isOriginal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get insertTime => $composableBuilder(
    column: $table.insertTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagRefreshTime => $composableBuilder(
    column: $table.tagRefreshTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parseSource => $composableBuilder(
    column: $table.parseSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sanitizedTitle => $composableBuilder(
    column: $table.sanitizedTitle,
    builder: (column) => ColumnFilters(column),
  );

  $$ContentCopyTableFilterComposer get copyId {
    final $$ContentCopyTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.copyId,
      referencedTable: $db.contentCopy,
      getReferencedColumn: (t) => t.copyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentCopyTableFilterComposer(
            $db: $db,
            $table: $db.contentCopy,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArchiveDownloadedTableOrderingComposer
    extends Composer<_$AppDb, $ArchiveDownloadedTable> {
  $$ArchiveDownloadedTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get gid => $composableBuilder(
    column: $table.gid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get token => $composableBuilder(
    column: $table.token,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get galleryUrl => $composableBuilder(
    column: $table.galleryUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploader => $composableBuilder(
    column: $table.uploader,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publishTime => $composableBuilder(
    column: $table.publishTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archiveStatusCode => $composableBuilder(
    column: $table.archiveStatusCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archivePageUrl => $composableBuilder(
    column: $table.archivePageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadPageUrl => $composableBuilder(
    column: $table.downloadPageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOriginal => $composableBuilder(
    column: $table.isOriginal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get insertTime => $composableBuilder(
    column: $table.insertTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagRefreshTime => $composableBuilder(
    column: $table.tagRefreshTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parseSource => $composableBuilder(
    column: $table.parseSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sanitizedTitle => $composableBuilder(
    column: $table.sanitizedTitle,
    builder: (column) => ColumnOrderings(column),
  );

  $$ContentCopyTableOrderingComposer get copyId {
    final $$ContentCopyTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.copyId,
      referencedTable: $db.contentCopy,
      getReferencedColumn: (t) => t.copyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentCopyTableOrderingComposer(
            $db: $db,
            $table: $db.contentCopy,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArchiveDownloadedTableAnnotationComposer
    extends Composer<_$AppDb, $ArchiveDownloadedTable> {
  $$ArchiveDownloadedTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get gid =>
      $composableBuilder(column: $table.gid, builder: (column) => column);

  GeneratedColumn<String> get token =>
      $composableBuilder(column: $table.token, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<String> get galleryUrl => $composableBuilder(
    column: $table.galleryUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get uploader =>
      $composableBuilder(column: $table.uploader, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get publishTime => $composableBuilder(
    column: $table.publishTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get archiveStatusCode => $composableBuilder(
    column: $table.archiveStatusCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get archivePageUrl => $composableBuilder(
    column: $table.archivePageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get downloadPageUrl => $composableBuilder(
    column: $table.downloadPageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isOriginal => $composableBuilder(
    column: $table.isOriginal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get insertTime => $composableBuilder(
    column: $table.insertTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get tagRefreshTime => $composableBuilder(
    column: $table.tagRefreshTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get parseSource => $composableBuilder(
    column: $table.parseSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sanitizedTitle => $composableBuilder(
    column: $table.sanitizedTitle,
    builder: (column) => column,
  );

  $$ContentCopyTableAnnotationComposer get copyId {
    final $$ContentCopyTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.copyId,
      referencedTable: $db.contentCopy,
      getReferencedColumn: (t) => t.copyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentCopyTableAnnotationComposer(
            $db: $db,
            $table: $db.contentCopy,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArchiveDownloadedTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ArchiveDownloadedTable,
          ArchiveDownloadedData,
          $$ArchiveDownloadedTableFilterComposer,
          $$ArchiveDownloadedTableOrderingComposer,
          $$ArchiveDownloadedTableAnnotationComposer,
          $$ArchiveDownloadedTableCreateCompanionBuilder,
          $$ArchiveDownloadedTableUpdateCompanionBuilder,
          (ArchiveDownloadedData, $$ArchiveDownloadedTableReferences),
          ArchiveDownloadedData,
          PrefetchHooks Function({bool copyId})
        > {
  $$ArchiveDownloadedTableTableManager(
    _$AppDb db,
    $ArchiveDownloadedTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArchiveDownloadedTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArchiveDownloadedTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArchiveDownloadedTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> gid = const Value.absent(),
                Value<String?> copyId = const Value.absent(),
                Value<String> token = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<String> galleryUrl = const Value.absent(),
                Value<String> coverUrl = const Value.absent(),
                Value<String?> uploader = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<String> publishTime = const Value.absent(),
                Value<int> archiveStatusCode = const Value.absent(),
                Value<String> archivePageUrl = const Value.absent(),
                Value<String?> downloadPageUrl = const Value.absent(),
                Value<String?> downloadUrl = const Value.absent(),
                Value<bool> isOriginal = const Value.absent(),
                Value<String> insertTime = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> groupName = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String?> tagRefreshTime = const Value.absent(),
                Value<int> parseSource = const Value.absent(),
                Value<String?> sanitizedTitle = const Value.absent(),
              }) => ArchiveDownloadedCompanion(
                gid: gid,
                copyId: copyId,
                token: token,
                title: title,
                category: category,
                pageCount: pageCount,
                galleryUrl: galleryUrl,
                coverUrl: coverUrl,
                uploader: uploader,
                size: size,
                publishTime: publishTime,
                archiveStatusCode: archiveStatusCode,
                archivePageUrl: archivePageUrl,
                downloadPageUrl: downloadPageUrl,
                downloadUrl: downloadUrl,
                isOriginal: isOriginal,
                insertTime: insertTime,
                sortOrder: sortOrder,
                groupName: groupName,
                tags: tags,
                tagRefreshTime: tagRefreshTime,
                parseSource: parseSource,
                sanitizedTitle: sanitizedTitle,
              ),
          createCompanionCallback:
              ({
                Value<int> gid = const Value.absent(),
                Value<String?> copyId = const Value.absent(),
                required String token,
                required String title,
                required String category,
                required int pageCount,
                required String galleryUrl,
                required String coverUrl,
                Value<String?> uploader = const Value.absent(),
                required int size,
                required String publishTime,
                required int archiveStatusCode,
                required String archivePageUrl,
                Value<String?> downloadPageUrl = const Value.absent(),
                Value<String?> downloadUrl = const Value.absent(),
                required bool isOriginal,
                required String insertTime,
                Value<int> sortOrder = const Value.absent(),
                required String groupName,
                Value<String> tags = const Value.absent(),
                Value<String?> tagRefreshTime = const Value.absent(),
                Value<int> parseSource = const Value.absent(),
                Value<String?> sanitizedTitle = const Value.absent(),
              }) => ArchiveDownloadedCompanion.insert(
                gid: gid,
                copyId: copyId,
                token: token,
                title: title,
                category: category,
                pageCount: pageCount,
                galleryUrl: galleryUrl,
                coverUrl: coverUrl,
                uploader: uploader,
                size: size,
                publishTime: publishTime,
                archiveStatusCode: archiveStatusCode,
                archivePageUrl: archivePageUrl,
                downloadPageUrl: downloadPageUrl,
                downloadUrl: downloadUrl,
                isOriginal: isOriginal,
                insertTime: insertTime,
                sortOrder: sortOrder,
                groupName: groupName,
                tags: tags,
                tagRefreshTime: tagRefreshTime,
                parseSource: parseSource,
                sanitizedTitle: sanitizedTitle,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArchiveDownloadedTable, ArchiveDownloadedData>(
                    table,
                  ),
                  $$ArchiveDownloadedTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({copyId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (copyId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.copyId,
                        referencedTable: $$ArchiveDownloadedTableReferences
                            ._copyIdTable(db),
                        referencedColumn: $$ArchiveDownloadedTableReferences
                            ._copyIdTable(db)
                            .copyId,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ArchiveDownloadedTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ArchiveDownloadedTable,
      ArchiveDownloadedData,
      $$ArchiveDownloadedTableFilterComposer,
      $$ArchiveDownloadedTableOrderingComposer,
      $$ArchiveDownloadedTableAnnotationComposer,
      $$ArchiveDownloadedTableCreateCompanionBuilder,
      $$ArchiveDownloadedTableUpdateCompanionBuilder,
      (ArchiveDownloadedData, $$ArchiveDownloadedTableReferences),
      ArchiveDownloadedData,
      PrefetchHooks Function({bool copyId})
    >;
typedef $$ArchiveGroupTableCreateCompanionBuilder =
    ArchiveGroupCompanion Function({
      required String groupName,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$ArchiveGroupTableUpdateCompanionBuilder =
    ArchiveGroupCompanion Function({
      Value<String> groupName,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$ArchiveGroupTableFilterComposer
    extends Composer<_$AppDb, $ArchiveGroupTable> {
  $$ArchiveGroupTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ArchiveGroupTableOrderingComposer
    extends Composer<_$AppDb, $ArchiveGroupTable> {
  $$ArchiveGroupTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArchiveGroupTableAnnotationComposer
    extends Composer<_$AppDb, $ArchiveGroupTable> {
  $$ArchiveGroupTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$ArchiveGroupTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ArchiveGroupTable,
          ArchiveGroupData,
          $$ArchiveGroupTableFilterComposer,
          $$ArchiveGroupTableOrderingComposer,
          $$ArchiveGroupTableAnnotationComposer,
          $$ArchiveGroupTableCreateCompanionBuilder,
          $$ArchiveGroupTableUpdateCompanionBuilder,
          (
            ArchiveGroupData,
            BaseReferences<_$AppDb, $ArchiveGroupTable, ArchiveGroupData>,
          ),
          ArchiveGroupData,
          PrefetchHooks Function()
        > {
  $$ArchiveGroupTableTableManager(_$AppDb db, $ArchiveGroupTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArchiveGroupTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArchiveGroupTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArchiveGroupTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> groupName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArchiveGroupCompanion(
                groupName: groupName,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String groupName,
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArchiveGroupCompanion.insert(
                groupName: groupName,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArchiveGroupTable, ArchiveGroupData>(table),
                  BaseReferences<_$AppDb, $ArchiveGroupTable, ArchiveGroupData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ArchiveGroupTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ArchiveGroupTable,
      ArchiveGroupData,
      $$ArchiveGroupTableFilterComposer,
      $$ArchiveGroupTableOrderingComposer,
      $$ArchiveGroupTableAnnotationComposer,
      $$ArchiveGroupTableCreateCompanionBuilder,
      $$ArchiveGroupTableUpdateCompanionBuilder,
      (
        ArchiveGroupData,
        BaseReferences<_$AppDb, $ArchiveGroupTable, ArchiveGroupData>,
      ),
      ArchiveGroupData,
      PrefetchHooks Function()
    >;
typedef $$GalleryDownloadedTableCreateCompanionBuilder =
    GalleryDownloadedCompanion Function({
      Value<int> gid,
      Value<String?> copyId,
      required String token,
      required String title,
      required String category,
      required int pageCount,
      required String galleryUrl,
      Value<String?> oldVersionGalleryUrl,
      Value<String?> uploader,
      required String publishTime,
      required int downloadStatusIndex,
      required String insertTime,
      Value<bool> downloadOriginalImage,
      required int priority,
      Value<int> sortOrder,
      required String groupName,
      Value<String> tags,
      Value<String?> tagRefreshTime,
      Value<String?> sanitizedTitle,
    });
typedef $$GalleryDownloadedTableUpdateCompanionBuilder =
    GalleryDownloadedCompanion Function({
      Value<int> gid,
      Value<String?> copyId,
      Value<String> token,
      Value<String> title,
      Value<String> category,
      Value<int> pageCount,
      Value<String> galleryUrl,
      Value<String?> oldVersionGalleryUrl,
      Value<String?> uploader,
      Value<String> publishTime,
      Value<int> downloadStatusIndex,
      Value<String> insertTime,
      Value<bool> downloadOriginalImage,
      Value<int> priority,
      Value<int> sortOrder,
      Value<String> groupName,
      Value<String> tags,
      Value<String?> tagRefreshTime,
      Value<String?> sanitizedTitle,
    });

final class $$GalleryDownloadedTableReferences
    extends
        BaseReferences<
          _$AppDb,
          $GalleryDownloadedTable,
          GalleryDownloadedData
        > {
  $$GalleryDownloadedTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ContentCopyTable _copyIdTable(_$AppDb db) => db.contentCopy
      .createAlias('gallery_downloaded_v2__copy_id__content_copy__copy_id');

  $$ContentCopyTableProcessedTableManager? get copyId {
    final $_column = $_itemColumn<String>('copy_id');
    if ($_column == null) return null;
    final manager = $$ContentCopyTableTableManager(
      $_db,
      $_db.contentCopy,
    ).filter((f) => f.copyId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_copyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ImageTable, List<ImageData>> _imageRefsTable(
    _$AppDb db,
  ) => MultiTypedResultKey.fromTable(
    db.image,
    aliasName: 'gallery_downloaded_v2__gid__image__gid',
  );

  $$ImageTableProcessedTableManager get imageRefs {
    final manager = $$ImageTableTableManager(
      $_db,
      $_db.image,
    ).filter((f) => f.gid.gid.sqlEquals($_itemColumn<int>('gid')!));

    final cache = $_typedResult.readTableOrNull(_imageRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GalleryDownloadedTableFilterComposer
    extends Composer<_$AppDb, $GalleryDownloadedTable> {
  $$GalleryDownloadedTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get gid => $composableBuilder(
    column: $table.gid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get token => $composableBuilder(
    column: $table.token,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get galleryUrl => $composableBuilder(
    column: $table.galleryUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oldVersionGalleryUrl => $composableBuilder(
    column: $table.oldVersionGalleryUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploader => $composableBuilder(
    column: $table.uploader,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publishTime => $composableBuilder(
    column: $table.publishTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadStatusIndex => $composableBuilder(
    column: $table.downloadStatusIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get insertTime => $composableBuilder(
    column: $table.insertTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get downloadOriginalImage => $composableBuilder(
    column: $table.downloadOriginalImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagRefreshTime => $composableBuilder(
    column: $table.tagRefreshTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sanitizedTitle => $composableBuilder(
    column: $table.sanitizedTitle,
    builder: (column) => ColumnFilters(column),
  );

  $$ContentCopyTableFilterComposer get copyId {
    final $$ContentCopyTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.copyId,
      referencedTable: $db.contentCopy,
      getReferencedColumn: (t) => t.copyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentCopyTableFilterComposer(
            $db: $db,
            $table: $db.contentCopy,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> imageRefs(
    Expression<bool> Function($$ImageTableFilterComposer f) f,
  ) {
    final $$ImageTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gid,
      referencedTable: $db.image,
      getReferencedColumn: (t) => t.gid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageTableFilterComposer(
            $db: $db,
            $table: $db.image,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GalleryDownloadedTableOrderingComposer
    extends Composer<_$AppDb, $GalleryDownloadedTable> {
  $$GalleryDownloadedTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get gid => $composableBuilder(
    column: $table.gid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get token => $composableBuilder(
    column: $table.token,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get galleryUrl => $composableBuilder(
    column: $table.galleryUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oldVersionGalleryUrl => $composableBuilder(
    column: $table.oldVersionGalleryUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploader => $composableBuilder(
    column: $table.uploader,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publishTime => $composableBuilder(
    column: $table.publishTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadStatusIndex => $composableBuilder(
    column: $table.downloadStatusIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get insertTime => $composableBuilder(
    column: $table.insertTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get downloadOriginalImage => $composableBuilder(
    column: $table.downloadOriginalImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagRefreshTime => $composableBuilder(
    column: $table.tagRefreshTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sanitizedTitle => $composableBuilder(
    column: $table.sanitizedTitle,
    builder: (column) => ColumnOrderings(column),
  );

  $$ContentCopyTableOrderingComposer get copyId {
    final $$ContentCopyTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.copyId,
      referencedTable: $db.contentCopy,
      getReferencedColumn: (t) => t.copyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentCopyTableOrderingComposer(
            $db: $db,
            $table: $db.contentCopy,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GalleryDownloadedTableAnnotationComposer
    extends Composer<_$AppDb, $GalleryDownloadedTable> {
  $$GalleryDownloadedTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get gid =>
      $composableBuilder(column: $table.gid, builder: (column) => column);

  GeneratedColumn<String> get token =>
      $composableBuilder(column: $table.token, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<String> get galleryUrl => $composableBuilder(
    column: $table.galleryUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get oldVersionGalleryUrl => $composableBuilder(
    column: $table.oldVersionGalleryUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uploader =>
      $composableBuilder(column: $table.uploader, builder: (column) => column);

  GeneratedColumn<String> get publishTime => $composableBuilder(
    column: $table.publishTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadStatusIndex => $composableBuilder(
    column: $table.downloadStatusIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get insertTime => $composableBuilder(
    column: $table.insertTime,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get downloadOriginalImage => $composableBuilder(
    column: $table.downloadOriginalImage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get tagRefreshTime => $composableBuilder(
    column: $table.tagRefreshTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sanitizedTitle => $composableBuilder(
    column: $table.sanitizedTitle,
    builder: (column) => column,
  );

  $$ContentCopyTableAnnotationComposer get copyId {
    final $$ContentCopyTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.copyId,
      referencedTable: $db.contentCopy,
      getReferencedColumn: (t) => t.copyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentCopyTableAnnotationComposer(
            $db: $db,
            $table: $db.contentCopy,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> imageRefs<T extends Object>(
    Expression<T> Function($$ImageTableAnnotationComposer a) f,
  ) {
    final $$ImageTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gid,
      referencedTable: $db.image,
      getReferencedColumn: (t) => t.gid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageTableAnnotationComposer(
            $db: $db,
            $table: $db.image,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GalleryDownloadedTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $GalleryDownloadedTable,
          GalleryDownloadedData,
          $$GalleryDownloadedTableFilterComposer,
          $$GalleryDownloadedTableOrderingComposer,
          $$GalleryDownloadedTableAnnotationComposer,
          $$GalleryDownloadedTableCreateCompanionBuilder,
          $$GalleryDownloadedTableUpdateCompanionBuilder,
          (GalleryDownloadedData, $$GalleryDownloadedTableReferences),
          GalleryDownloadedData,
          PrefetchHooks Function({bool copyId, bool imageRefs})
        > {
  $$GalleryDownloadedTableTableManager(
    _$AppDb db,
    $GalleryDownloadedTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GalleryDownloadedTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GalleryDownloadedTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GalleryDownloadedTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> gid = const Value.absent(),
                Value<String?> copyId = const Value.absent(),
                Value<String> token = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<String> galleryUrl = const Value.absent(),
                Value<String?> oldVersionGalleryUrl = const Value.absent(),
                Value<String?> uploader = const Value.absent(),
                Value<String> publishTime = const Value.absent(),
                Value<int> downloadStatusIndex = const Value.absent(),
                Value<String> insertTime = const Value.absent(),
                Value<bool> downloadOriginalImage = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> groupName = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String?> tagRefreshTime = const Value.absent(),
                Value<String?> sanitizedTitle = const Value.absent(),
              }) => GalleryDownloadedCompanion(
                gid: gid,
                copyId: copyId,
                token: token,
                title: title,
                category: category,
                pageCount: pageCount,
                galleryUrl: galleryUrl,
                oldVersionGalleryUrl: oldVersionGalleryUrl,
                uploader: uploader,
                publishTime: publishTime,
                downloadStatusIndex: downloadStatusIndex,
                insertTime: insertTime,
                downloadOriginalImage: downloadOriginalImage,
                priority: priority,
                sortOrder: sortOrder,
                groupName: groupName,
                tags: tags,
                tagRefreshTime: tagRefreshTime,
                sanitizedTitle: sanitizedTitle,
              ),
          createCompanionCallback:
              ({
                Value<int> gid = const Value.absent(),
                Value<String?> copyId = const Value.absent(),
                required String token,
                required String title,
                required String category,
                required int pageCount,
                required String galleryUrl,
                Value<String?> oldVersionGalleryUrl = const Value.absent(),
                Value<String?> uploader = const Value.absent(),
                required String publishTime,
                required int downloadStatusIndex,
                required String insertTime,
                Value<bool> downloadOriginalImage = const Value.absent(),
                required int priority,
                Value<int> sortOrder = const Value.absent(),
                required String groupName,
                Value<String> tags = const Value.absent(),
                Value<String?> tagRefreshTime = const Value.absent(),
                Value<String?> sanitizedTitle = const Value.absent(),
              }) => GalleryDownloadedCompanion.insert(
                gid: gid,
                copyId: copyId,
                token: token,
                title: title,
                category: category,
                pageCount: pageCount,
                galleryUrl: galleryUrl,
                oldVersionGalleryUrl: oldVersionGalleryUrl,
                uploader: uploader,
                publishTime: publishTime,
                downloadStatusIndex: downloadStatusIndex,
                insertTime: insertTime,
                downloadOriginalImage: downloadOriginalImage,
                priority: priority,
                sortOrder: sortOrder,
                groupName: groupName,
                tags: tags,
                tagRefreshTime: tagRefreshTime,
                sanitizedTitle: sanitizedTitle,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GalleryDownloadedTable, GalleryDownloadedData>(
                    table,
                  ),
                  $$GalleryDownloadedTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({copyId = false, imageRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (imageRefs) db.image],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (copyId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.copyId,
                        referencedTable: $$GalleryDownloadedTableReferences
                            ._copyIdTable(db),
                        referencedColumn: $$GalleryDownloadedTableReferences
                            ._copyIdTable(db)
                            .copyId,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (imageRefs)
                    await $_getPrefetchedDataByColumns<
                      GalleryDownloadedData,
                      $GalleryDownloadedTable,
                      ImageData,
                      $ImageTable
                    >(
                      currentTable: table,
                      referencedTable: $$GalleryDownloadedTableReferences
                          ._imageRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$GalleryDownloadedTableReferences(
                            db,
                            table,
                            p0,
                          ).imageRefs,
                      currentColumn: 'gid',
                      referencedColumn: 'gid',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$GalleryDownloadedTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $GalleryDownloadedTable,
      GalleryDownloadedData,
      $$GalleryDownloadedTableFilterComposer,
      $$GalleryDownloadedTableOrderingComposer,
      $$GalleryDownloadedTableAnnotationComposer,
      $$GalleryDownloadedTableCreateCompanionBuilder,
      $$GalleryDownloadedTableUpdateCompanionBuilder,
      (GalleryDownloadedData, $$GalleryDownloadedTableReferences),
      GalleryDownloadedData,
      PrefetchHooks Function({bool copyId, bool imageRefs})
    >;
typedef $$GalleryGroupTableCreateCompanionBuilder =
    GalleryGroupCompanion Function({
      required String groupName,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$GalleryGroupTableUpdateCompanionBuilder =
    GalleryGroupCompanion Function({
      Value<String> groupName,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$GalleryGroupTableFilterComposer
    extends Composer<_$AppDb, $GalleryGroupTable> {
  $$GalleryGroupTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GalleryGroupTableOrderingComposer
    extends Composer<_$AppDb, $GalleryGroupTable> {
  $$GalleryGroupTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GalleryGroupTableAnnotationComposer
    extends Composer<_$AppDb, $GalleryGroupTable> {
  $$GalleryGroupTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$GalleryGroupTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $GalleryGroupTable,
          GalleryGroupData,
          $$GalleryGroupTableFilterComposer,
          $$GalleryGroupTableOrderingComposer,
          $$GalleryGroupTableAnnotationComposer,
          $$GalleryGroupTableCreateCompanionBuilder,
          $$GalleryGroupTableUpdateCompanionBuilder,
          (
            GalleryGroupData,
            BaseReferences<_$AppDb, $GalleryGroupTable, GalleryGroupData>,
          ),
          GalleryGroupData,
          PrefetchHooks Function()
        > {
  $$GalleryGroupTableTableManager(_$AppDb db, $GalleryGroupTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GalleryGroupTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GalleryGroupTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GalleryGroupTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> groupName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GalleryGroupCompanion(
                groupName: groupName,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String groupName,
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GalleryGroupCompanion.insert(
                groupName: groupName,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GalleryGroupTable, GalleryGroupData>(table),
                  BaseReferences<_$AppDb, $GalleryGroupTable, GalleryGroupData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GalleryGroupTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $GalleryGroupTable,
      GalleryGroupData,
      $$GalleryGroupTableFilterComposer,
      $$GalleryGroupTableOrderingComposer,
      $$GalleryGroupTableAnnotationComposer,
      $$GalleryGroupTableCreateCompanionBuilder,
      $$GalleryGroupTableUpdateCompanionBuilder,
      (
        GalleryGroupData,
        BaseReferences<_$AppDb, $GalleryGroupTable, GalleryGroupData>,
      ),
      GalleryGroupData,
      PrefetchHooks Function()
    >;
typedef $$ImageTableCreateCompanionBuilder = ImageCompanion Function({
  required int gid,
  required String url,
  Value<String?> originalImageUrl,
  required int serialNo,
  required String path,
  required String imageHash,
  required int downloadStatusIndex,
  Value<int> rowid,
});
typedef $$ImageTableUpdateCompanionBuilder = ImageCompanion Function({
  Value<int> gid,
  Value<String> url,
  Value<String?> originalImageUrl,
  Value<int> serialNo,
  Value<String> path,
  Value<String> imageHash,
  Value<int> downloadStatusIndex,
  Value<int> rowid,
});

final class $$ImageTableReferences
    extends BaseReferences<_$AppDb, $ImageTable, ImageData> {
  $$ImageTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GalleryDownloadedTable _gidTable(_$AppDb db) => db.galleryDownloaded
      .createAlias('image__gid__gallery_downloaded_v2__gid');

  $$GalleryDownloadedTableProcessedTableManager get gid {
    final $_column = $_itemColumn<int>('gid')!;

    final manager = $$GalleryDownloadedTableTableManager(
      $_db,
      $_db.galleryDownloaded,
    ).filter((f) => f.gid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_gidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ImageTableFilterComposer extends Composer<_$AppDb, $ImageTable> {
  $$ImageTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalImageUrl => $composableBuilder(
    column: $table.originalImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serialNo => $composableBuilder(
    column: $table.serialNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageHash => $composableBuilder(
    column: $table.imageHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadStatusIndex => $composableBuilder(
    column: $table.downloadStatusIndex,
    builder: (column) => ColumnFilters(column),
  );

  $$GalleryDownloadedTableFilterComposer get gid {
    final $$GalleryDownloadedTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gid,
      referencedTable: $db.galleryDownloaded,
      getReferencedColumn: (t) => t.gid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryDownloadedTableFilterComposer(
            $db: $db,
            $table: $db.galleryDownloaded,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImageTableOrderingComposer extends Composer<_$AppDb, $ImageTable> {
  $$ImageTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalImageUrl => $composableBuilder(
    column: $table.originalImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serialNo => $composableBuilder(
    column: $table.serialNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageHash => $composableBuilder(
    column: $table.imageHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadStatusIndex => $composableBuilder(
    column: $table.downloadStatusIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $$GalleryDownloadedTableOrderingComposer get gid {
    final $$GalleryDownloadedTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gid,
      referencedTable: $db.galleryDownloaded,
      getReferencedColumn: (t) => t.gid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryDownloadedTableOrderingComposer(
            $db: $db,
            $table: $db.galleryDownloaded,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImageTableAnnotationComposer extends Composer<_$AppDb, $ImageTable> {
  $$ImageTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get originalImageUrl => $composableBuilder(
    column: $table.originalImageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serialNo =>
      $composableBuilder(column: $table.serialNo, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get imageHash =>
      $composableBuilder(column: $table.imageHash, builder: (column) => column);

  GeneratedColumn<int> get downloadStatusIndex => $composableBuilder(
    column: $table.downloadStatusIndex,
    builder: (column) => column,
  );

  $$GalleryDownloadedTableAnnotationComposer get gid {
    final $$GalleryDownloadedTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.gid,
          referencedTable: $db.galleryDownloaded,
          getReferencedColumn: (t) => t.gid,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GalleryDownloadedTableAnnotationComposer(
                $db: $db,
                $table: $db.galleryDownloaded,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ImageTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ImageTable,
          ImageData,
          $$ImageTableFilterComposer,
          $$ImageTableOrderingComposer,
          $$ImageTableAnnotationComposer,
          $$ImageTableCreateCompanionBuilder,
          $$ImageTableUpdateCompanionBuilder,
          (ImageData, $$ImageTableReferences),
          ImageData,
          PrefetchHooks Function({bool gid})
        > {
  $$ImageTableTableManager(_$AppDb db, $ImageTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImageTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImageTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImageTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> gid = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> originalImageUrl = const Value.absent(),
                Value<int> serialNo = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> imageHash = const Value.absent(),
                Value<int> downloadStatusIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImageCompanion(
                gid: gid,
                url: url,
                originalImageUrl: originalImageUrl,
                serialNo: serialNo,
                path: path,
                imageHash: imageHash,
                downloadStatusIndex: downloadStatusIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int gid,
                required String url,
                Value<String?> originalImageUrl = const Value.absent(),
                required int serialNo,
                required String path,
                required String imageHash,
                required int downloadStatusIndex,
                Value<int> rowid = const Value.absent(),
              }) => ImageCompanion.insert(
                gid: gid,
                url: url,
                originalImageUrl: originalImageUrl,
                serialNo: serialNo,
                path: path,
                imageHash: imageHash,
                downloadStatusIndex: downloadStatusIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ImageTable, ImageData>(table),
                  $$ImageTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({gid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (gid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.gid,
                        referencedTable: $$ImageTableReferences._gidTable(db),
                        referencedColumn: $$ImageTableReferences
                            ._gidTable(db)
                            .gid,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ImageTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ImageTable,
      ImageData,
      $$ImageTableFilterComposer,
      $$ImageTableOrderingComposer,
      $$ImageTableAnnotationComposer,
      $$ImageTableCreateCompanionBuilder,
      $$ImageTableUpdateCompanionBuilder,
      (ImageData, $$ImageTableReferences),
      ImageData,
      PrefetchHooks Function({bool gid})
    >;
typedef $$GalleryHistoryV2TableCreateCompanionBuilder =
    GalleryHistoryV2Companion Function({
      Value<int> gid,
      required String jsonBody,
      required String lastReadTime,
    });
typedef $$GalleryHistoryV2TableUpdateCompanionBuilder =
    GalleryHistoryV2Companion Function({
      Value<int> gid,
      Value<String> jsonBody,
      Value<String> lastReadTime,
    });

class $$GalleryHistoryV2TableFilterComposer
    extends Composer<_$AppDb, $GalleryHistoryV2Table> {
  $$GalleryHistoryV2TableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get gid => $composableBuilder(
    column: $table.gid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jsonBody => $composableBuilder(
    column: $table.jsonBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastReadTime => $composableBuilder(
    column: $table.lastReadTime,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GalleryHistoryV2TableOrderingComposer
    extends Composer<_$AppDb, $GalleryHistoryV2Table> {
  $$GalleryHistoryV2TableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get gid => $composableBuilder(
    column: $table.gid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jsonBody => $composableBuilder(
    column: $table.jsonBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastReadTime => $composableBuilder(
    column: $table.lastReadTime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GalleryHistoryV2TableAnnotationComposer
    extends Composer<_$AppDb, $GalleryHistoryV2Table> {
  $$GalleryHistoryV2TableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get gid =>
      $composableBuilder(column: $table.gid, builder: (column) => column);

  GeneratedColumn<String> get jsonBody =>
      $composableBuilder(column: $table.jsonBody, builder: (column) => column);

  GeneratedColumn<String> get lastReadTime => $composableBuilder(
    column: $table.lastReadTime,
    builder: (column) => column,
  );
}

class $$GalleryHistoryV2TableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $GalleryHistoryV2Table,
          GalleryHistoryV2Data,
          $$GalleryHistoryV2TableFilterComposer,
          $$GalleryHistoryV2TableOrderingComposer,
          $$GalleryHistoryV2TableAnnotationComposer,
          $$GalleryHistoryV2TableCreateCompanionBuilder,
          $$GalleryHistoryV2TableUpdateCompanionBuilder,
          (
            GalleryHistoryV2Data,
            BaseReferences<
              _$AppDb,
              $GalleryHistoryV2Table,
              GalleryHistoryV2Data
            >,
          ),
          GalleryHistoryV2Data,
          PrefetchHooks Function()
        > {
  $$GalleryHistoryV2TableTableManager(_$AppDb db, $GalleryHistoryV2Table table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GalleryHistoryV2TableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GalleryHistoryV2TableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GalleryHistoryV2TableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> gid = const Value.absent(),
                Value<String> jsonBody = const Value.absent(),
                Value<String> lastReadTime = const Value.absent(),
              }) => GalleryHistoryV2Companion(
                gid: gid,
                jsonBody: jsonBody,
                lastReadTime: lastReadTime,
              ),
          createCompanionCallback:
              ({
                Value<int> gid = const Value.absent(),
                required String jsonBody,
                required String lastReadTime,
              }) => GalleryHistoryV2Companion.insert(
                gid: gid,
                jsonBody: jsonBody,
                lastReadTime: lastReadTime,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GalleryHistoryV2Table, GalleryHistoryV2Data>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDb,
                    $GalleryHistoryV2Table,
                    GalleryHistoryV2Data
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GalleryHistoryV2TableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $GalleryHistoryV2Table,
      GalleryHistoryV2Data,
      $$GalleryHistoryV2TableFilterComposer,
      $$GalleryHistoryV2TableOrderingComposer,
      $$GalleryHistoryV2TableAnnotationComposer,
      $$GalleryHistoryV2TableCreateCompanionBuilder,
      $$GalleryHistoryV2TableUpdateCompanionBuilder,
      (
        GalleryHistoryV2Data,
        BaseReferences<_$AppDb, $GalleryHistoryV2Table, GalleryHistoryV2Data>,
      ),
      GalleryHistoryV2Data,
      PrefetchHooks Function()
    >;
typedef $$TagCountTableCreateCompanionBuilder = TagCountCompanion Function({
  required String namespaceWithKey,
  required int count,
  Value<int> rowid,
});
typedef $$TagCountTableUpdateCompanionBuilder = TagCountCompanion Function({
  Value<String> namespaceWithKey,
  Value<int> count,
  Value<int> rowid,
});

class $$TagCountTableFilterComposer extends Composer<_$AppDb, $TagCountTable> {
  $$TagCountTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get namespaceWithKey => $composableBuilder(
    column: $table.namespaceWithKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagCountTableOrderingComposer
    extends Composer<_$AppDb, $TagCountTable> {
  $$TagCountTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get namespaceWithKey => $composableBuilder(
    column: $table.namespaceWithKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagCountTableAnnotationComposer
    extends Composer<_$AppDb, $TagCountTable> {
  $$TagCountTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get namespaceWithKey => $composableBuilder(
    column: $table.namespaceWithKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);
}

class $$TagCountTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $TagCountTable,
          TagCountData,
          $$TagCountTableFilterComposer,
          $$TagCountTableOrderingComposer,
          $$TagCountTableAnnotationComposer,
          $$TagCountTableCreateCompanionBuilder,
          $$TagCountTableUpdateCompanionBuilder,
          (TagCountData, BaseReferences<_$AppDb, $TagCountTable, TagCountData>),
          TagCountData,
          PrefetchHooks Function()
        > {
  $$TagCountTableTableManager(_$AppDb db, $TagCountTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagCountTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagCountTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagCountTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> namespaceWithKey = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagCountCompanion(
                namespaceWithKey: namespaceWithKey,
                count: count,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String namespaceWithKey,
                required int count,
                Value<int> rowid = const Value.absent(),
              }) => TagCountCompanion.insert(
                namespaceWithKey: namespaceWithKey,
                count: count,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagCountTable, TagCountData>(table),
                  BaseReferences<_$AppDb, $TagCountTable, TagCountData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagCountTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $TagCountTable,
      TagCountData,
      $$TagCountTableFilterComposer,
      $$TagCountTableOrderingComposer,
      $$TagCountTableAnnotationComposer,
      $$TagCountTableCreateCompanionBuilder,
      $$TagCountTableUpdateCompanionBuilder,
      (TagCountData, BaseReferences<_$AppDb, $TagCountTable, TagCountData>),
      TagCountData,
      PrefetchHooks Function()
    >;
typedef $$DioCacheTableCreateCompanionBuilder = DioCacheCompanion Function({
  required String cacheKey,
  required String url,
  required DateTime expireDate,
  required Uint8List content,
  required Uint8List headers,
  Value<int> rowid,
});
typedef $$DioCacheTableUpdateCompanionBuilder = DioCacheCompanion Function({
  Value<String> cacheKey,
  Value<String> url,
  Value<DateTime> expireDate,
  Value<Uint8List> content,
  Value<Uint8List> headers,
  Value<int> rowid,
});

class $$DioCacheTableFilterComposer extends Composer<_$AppDb, $DioCacheTable> {
  $$DioCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expireDate => $composableBuilder(
    column: $table.expireDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get headers => $composableBuilder(
    column: $table.headers,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DioCacheTableOrderingComposer
    extends Composer<_$AppDb, $DioCacheTable> {
  $$DioCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expireDate => $composableBuilder(
    column: $table.expireDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get headers => $composableBuilder(
    column: $table.headers,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DioCacheTableAnnotationComposer
    extends Composer<_$AppDb, $DioCacheTable> {
  $$DioCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<DateTime> get expireDate => $composableBuilder(
    column: $table.expireDate,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<Uint8List> get headers =>
      $composableBuilder(column: $table.headers, builder: (column) => column);
}

class $$DioCacheTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $DioCacheTable,
          DioCacheData,
          $$DioCacheTableFilterComposer,
          $$DioCacheTableOrderingComposer,
          $$DioCacheTableAnnotationComposer,
          $$DioCacheTableCreateCompanionBuilder,
          $$DioCacheTableUpdateCompanionBuilder,
          (DioCacheData, BaseReferences<_$AppDb, $DioCacheTable, DioCacheData>),
          DioCacheData,
          PrefetchHooks Function()
        > {
  $$DioCacheTableTableManager(_$AppDb db, $DioCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DioCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DioCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DioCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<DateTime> expireDate = const Value.absent(),
                Value<Uint8List> content = const Value.absent(),
                Value<Uint8List> headers = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DioCacheCompanion(
                cacheKey: cacheKey,
                url: url,
                expireDate: expireDate,
                content: content,
                headers: headers,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String url,
                required DateTime expireDate,
                required Uint8List content,
                required Uint8List headers,
                Value<int> rowid = const Value.absent(),
              }) => DioCacheCompanion.insert(
                cacheKey: cacheKey,
                url: url,
                expireDate: expireDate,
                content: content,
                headers: headers,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DioCacheTable, DioCacheData>(table),
                  BaseReferences<_$AppDb, $DioCacheTable, DioCacheData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DioCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $DioCacheTable,
      DioCacheData,
      $$DioCacheTableFilterComposer,
      $$DioCacheTableOrderingComposer,
      $$DioCacheTableAnnotationComposer,
      $$DioCacheTableCreateCompanionBuilder,
      $$DioCacheTableUpdateCompanionBuilder,
      (DioCacheData, BaseReferences<_$AppDb, $DioCacheTable, DioCacheData>),
      DioCacheData,
      PrefetchHooks Function()
    >;
typedef $$BlockRuleTableCreateCompanionBuilder = BlockRuleCompanion Function({
  Value<int> id,
  required String groupId,
  required int target,
  required int attribute,
  required int pattern,
  required String expression,
});
typedef $$BlockRuleTableUpdateCompanionBuilder = BlockRuleCompanion Function({
  Value<int> id,
  Value<String> groupId,
  Value<int> target,
  Value<int> attribute,
  Value<int> pattern,
  Value<String> expression,
});

class $$BlockRuleTableFilterComposer
    extends Composer<_$AppDb, $BlockRuleTable> {
  $$BlockRuleTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attribute => $composableBuilder(
    column: $table.attribute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BlockRuleTableOrderingComposer
    extends Composer<_$AppDb, $BlockRuleTable> {
  $$BlockRuleTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attribute => $composableBuilder(
    column: $table.attribute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BlockRuleTableAnnotationComposer
    extends Composer<_$AppDb, $BlockRuleTable> {
  $$BlockRuleTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<int> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<int> get attribute =>
      $composableBuilder(column: $table.attribute, builder: (column) => column);

  GeneratedColumn<int> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => column,
  );
}

class $$BlockRuleTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $BlockRuleTable,
          BlockRuleData,
          $$BlockRuleTableFilterComposer,
          $$BlockRuleTableOrderingComposer,
          $$BlockRuleTableAnnotationComposer,
          $$BlockRuleTableCreateCompanionBuilder,
          $$BlockRuleTableUpdateCompanionBuilder,
          (
            BlockRuleData,
            BaseReferences<_$AppDb, $BlockRuleTable, BlockRuleData>,
          ),
          BlockRuleData,
          PrefetchHooks Function()
        > {
  $$BlockRuleTableTableManager(_$AppDb db, $BlockRuleTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlockRuleTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlockRuleTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlockRuleTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<int> target = const Value.absent(),
                Value<int> attribute = const Value.absent(),
                Value<int> pattern = const Value.absent(),
                Value<String> expression = const Value.absent(),
              }) => BlockRuleCompanion(
                id: id,
                groupId: groupId,
                target: target,
                attribute: attribute,
                pattern: pattern,
                expression: expression,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String groupId,
                required int target,
                required int attribute,
                required int pattern,
                required String expression,
              }) => BlockRuleCompanion.insert(
                id: id,
                groupId: groupId,
                target: target,
                attribute: attribute,
                pattern: pattern,
                expression: expression,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BlockRuleTable, BlockRuleData>(table),
                  BaseReferences<_$AppDb, $BlockRuleTable, BlockRuleData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BlockRuleTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $BlockRuleTable,
      BlockRuleData,
      $$BlockRuleTableFilterComposer,
      $$BlockRuleTableOrderingComposer,
      $$BlockRuleTableAnnotationComposer,
      $$BlockRuleTableCreateCompanionBuilder,
      $$BlockRuleTableUpdateCompanionBuilder,
      (BlockRuleData, BaseReferences<_$AppDb, $BlockRuleTable, BlockRuleData>),
      BlockRuleData,
      PrefetchHooks Function()
    >;
typedef $$LocalConfigTableCreateCompanionBuilder =
    LocalConfigCompanion Function({
      required String configKey,
      required String subConfigKey,
      required String value,
      required String utime,
      Value<int> rowid,
    });
typedef $$LocalConfigTableUpdateCompanionBuilder =
    LocalConfigCompanion Function({
      Value<String> configKey,
      Value<String> subConfigKey,
      Value<String> value,
      Value<String> utime,
      Value<int> rowid,
    });

class $$LocalConfigTableFilterComposer
    extends Composer<_$AppDb, $LocalConfigTable> {
  $$LocalConfigTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get configKey => $composableBuilder(
    column: $table.configKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subConfigKey => $composableBuilder(
    column: $table.subConfigKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get utime => $composableBuilder(
    column: $table.utime,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalConfigTableOrderingComposer
    extends Composer<_$AppDb, $LocalConfigTable> {
  $$LocalConfigTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get configKey => $composableBuilder(
    column: $table.configKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subConfigKey => $composableBuilder(
    column: $table.subConfigKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get utime => $composableBuilder(
    column: $table.utime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalConfigTableAnnotationComposer
    extends Composer<_$AppDb, $LocalConfigTable> {
  $$LocalConfigTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get configKey =>
      $composableBuilder(column: $table.configKey, builder: (column) => column);

  GeneratedColumn<String> get subConfigKey => $composableBuilder(
    column: $table.subConfigKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get utime =>
      $composableBuilder(column: $table.utime, builder: (column) => column);
}

class $$LocalConfigTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $LocalConfigTable,
          LocalConfigData,
          $$LocalConfigTableFilterComposer,
          $$LocalConfigTableOrderingComposer,
          $$LocalConfigTableAnnotationComposer,
          $$LocalConfigTableCreateCompanionBuilder,
          $$LocalConfigTableUpdateCompanionBuilder,
          (
            LocalConfigData,
            BaseReferences<_$AppDb, $LocalConfigTable, LocalConfigData>,
          ),
          LocalConfigData,
          PrefetchHooks Function()
        > {
  $$LocalConfigTableTableManager(_$AppDb db, $LocalConfigTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalConfigTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalConfigTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalConfigTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> configKey = const Value.absent(),
                Value<String> subConfigKey = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> utime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalConfigCompanion(
                configKey: configKey,
                subConfigKey: subConfigKey,
                value: value,
                utime: utime,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String configKey,
                required String subConfigKey,
                required String value,
                required String utime,
                Value<int> rowid = const Value.absent(),
              }) => LocalConfigCompanion.insert(
                configKey: configKey,
                subConfigKey: subConfigKey,
                value: value,
                utime: utime,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalConfigTable, LocalConfigData>(table),
                  BaseReferences<_$AppDb, $LocalConfigTable, LocalConfigData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalConfigTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $LocalConfigTable,
      LocalConfigData,
      $$LocalConfigTableFilterComposer,
      $$LocalConfigTableOrderingComposer,
      $$LocalConfigTableAnnotationComposer,
      $$LocalConfigTableCreateCompanionBuilder,
      $$LocalConfigTableUpdateCompanionBuilder,
      (
        LocalConfigData,
        BaseReferences<_$AppDb, $LocalConfigTable, LocalConfigData>,
      ),
      LocalConfigData,
      PrefetchHooks Function()
    >;
typedef $$ContentPageTableCreateCompanionBuilder =
    ContentPageCompanion Function({
      required String copyId,
      required int ordinal,
      required String relativePath,
      Value<String?> rawHash,
      Value<int?> rawLength,
      Value<String?> codecProfile,
      Value<String?> objectHash,
      Value<int?> storedLength,
      Value<String?> mime,
      Value<int?> width,
      Value<int?> height,
      Value<String?> sourcePageUrl,
      required String state,
      Value<int> rowid,
    });
typedef $$ContentPageTableUpdateCompanionBuilder =
    ContentPageCompanion Function({
      Value<String> copyId,
      Value<int> ordinal,
      Value<String> relativePath,
      Value<String?> rawHash,
      Value<int?> rawLength,
      Value<String?> codecProfile,
      Value<String?> objectHash,
      Value<int?> storedLength,
      Value<String?> mime,
      Value<int?> width,
      Value<int?> height,
      Value<String?> sourcePageUrl,
      Value<String> state,
      Value<int> rowid,
    });

class $$ContentPageTableFilterComposer
    extends Composer<_$AppDb, $ContentPageTable> {
  $$ContentPageTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get copyId => $composableBuilder(
    column: $table.copyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawHash => $composableBuilder(
    column: $table.rawHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rawLength => $composableBuilder(
    column: $table.rawLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get codecProfile => $composableBuilder(
    column: $table.codecProfile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objectHash => $composableBuilder(
    column: $table.objectHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storedLength => $composableBuilder(
    column: $table.storedLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePageUrl => $composableBuilder(
    column: $table.sourcePageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentPageTableOrderingComposer
    extends Composer<_$AppDb, $ContentPageTable> {
  $$ContentPageTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get copyId => $composableBuilder(
    column: $table.copyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawHash => $composableBuilder(
    column: $table.rawHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rawLength => $composableBuilder(
    column: $table.rawLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get codecProfile => $composableBuilder(
    column: $table.codecProfile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objectHash => $composableBuilder(
    column: $table.objectHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storedLength => $composableBuilder(
    column: $table.storedLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePageUrl => $composableBuilder(
    column: $table.sourcePageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentPageTableAnnotationComposer
    extends Composer<_$AppDb, $ContentPageTable> {
  $$ContentPageTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get copyId =>
      $composableBuilder(column: $table.copyId, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawHash =>
      $composableBuilder(column: $table.rawHash, builder: (column) => column);

  GeneratedColumn<int> get rawLength =>
      $composableBuilder(column: $table.rawLength, builder: (column) => column);

  GeneratedColumn<String> get codecProfile => $composableBuilder(
    column: $table.codecProfile,
    builder: (column) => column,
  );

  GeneratedColumn<String> get objectHash => $composableBuilder(
    column: $table.objectHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get storedLength => $composableBuilder(
    column: $table.storedLength,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get sourcePageUrl => $composableBuilder(
    column: $table.sourcePageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);
}

class $$ContentPageTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ContentPageTable,
          ContentPageData,
          $$ContentPageTableFilterComposer,
          $$ContentPageTableOrderingComposer,
          $$ContentPageTableAnnotationComposer,
          $$ContentPageTableCreateCompanionBuilder,
          $$ContentPageTableUpdateCompanionBuilder,
          (
            ContentPageData,
            BaseReferences<_$AppDb, $ContentPageTable, ContentPageData>,
          ),
          ContentPageData,
          PrefetchHooks Function()
        > {
  $$ContentPageTableTableManager(_$AppDb db, $ContentPageTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentPageTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentPageTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentPageTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> copyId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String?> rawHash = const Value.absent(),
                Value<int?> rawLength = const Value.absent(),
                Value<String?> codecProfile = const Value.absent(),
                Value<String?> objectHash = const Value.absent(),
                Value<int?> storedLength = const Value.absent(),
                Value<String?> mime = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String?> sourcePageUrl = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentPageCompanion(
                copyId: copyId,
                ordinal: ordinal,
                relativePath: relativePath,
                rawHash: rawHash,
                rawLength: rawLength,
                codecProfile: codecProfile,
                objectHash: objectHash,
                storedLength: storedLength,
                mime: mime,
                width: width,
                height: height,
                sourcePageUrl: sourcePageUrl,
                state: state,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String copyId,
                required int ordinal,
                required String relativePath,
                Value<String?> rawHash = const Value.absent(),
                Value<int?> rawLength = const Value.absent(),
                Value<String?> codecProfile = const Value.absent(),
                Value<String?> objectHash = const Value.absent(),
                Value<int?> storedLength = const Value.absent(),
                Value<String?> mime = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String?> sourcePageUrl = const Value.absent(),
                required String state,
                Value<int> rowid = const Value.absent(),
              }) => ContentPageCompanion.insert(
                copyId: copyId,
                ordinal: ordinal,
                relativePath: relativePath,
                rawHash: rawHash,
                rawLength: rawLength,
                codecProfile: codecProfile,
                objectHash: objectHash,
                storedLength: storedLength,
                mime: mime,
                width: width,
                height: height,
                sourcePageUrl: sourcePageUrl,
                state: state,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContentPageTable, ContentPageData>(table),
                  BaseReferences<_$AppDb, $ContentPageTable, ContentPageData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentPageTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ContentPageTable,
      ContentPageData,
      $$ContentPageTableFilterComposer,
      $$ContentPageTableOrderingComposer,
      $$ContentPageTableAnnotationComposer,
      $$ContentPageTableCreateCompanionBuilder,
      $$ContentPageTableUpdateCompanionBuilder,
      (
        ContentPageData,
        BaseReferences<_$AppDb, $ContentPageTable, ContentPageData>,
      ),
      ContentPageData,
      PrefetchHooks Function()
    >;
typedef $$ContentRemoteResourceTableCreateCompanionBuilder =
    ContentRemoteResourceCompanion Function({
      required String targetNamespace,
      required String href,
      required String kind,
      Value<String?> objectHash,
      Value<String?> etag,
      Value<String?> partition,
      required String observedAt,
      Value<int> rowid,
    });
typedef $$ContentRemoteResourceTableUpdateCompanionBuilder =
    ContentRemoteResourceCompanion Function({
      Value<String> targetNamespace,
      Value<String> href,
      Value<String> kind,
      Value<String?> objectHash,
      Value<String?> etag,
      Value<String?> partition,
      Value<String> observedAt,
      Value<int> rowid,
    });

class $$ContentRemoteResourceTableFilterComposer
    extends Composer<_$AppDb, $ContentRemoteResourceTable> {
  $$ContentRemoteResourceTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get targetNamespace => $composableBuilder(
    column: $table.targetNamespace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get href => $composableBuilder(
    column: $table.href,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objectHash => $composableBuilder(
    column: $table.objectHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partition => $composableBuilder(
    column: $table.partition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentRemoteResourceTableOrderingComposer
    extends Composer<_$AppDb, $ContentRemoteResourceTable> {
  $$ContentRemoteResourceTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get targetNamespace => $composableBuilder(
    column: $table.targetNamespace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get href => $composableBuilder(
    column: $table.href,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objectHash => $composableBuilder(
    column: $table.objectHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partition => $composableBuilder(
    column: $table.partition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentRemoteResourceTableAnnotationComposer
    extends Composer<_$AppDb, $ContentRemoteResourceTable> {
  $$ContentRemoteResourceTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get targetNamespace => $composableBuilder(
    column: $table.targetNamespace,
    builder: (column) => column,
  );

  GeneratedColumn<String> get href =>
      $composableBuilder(column: $table.href, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get objectHash => $composableBuilder(
    column: $table.objectHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<String> get partition =>
      $composableBuilder(column: $table.partition, builder: (column) => column);

  GeneratedColumn<String> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => column,
  );
}

class $$ContentRemoteResourceTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ContentRemoteResourceTable,
          ContentRemoteResourceData,
          $$ContentRemoteResourceTableFilterComposer,
          $$ContentRemoteResourceTableOrderingComposer,
          $$ContentRemoteResourceTableAnnotationComposer,
          $$ContentRemoteResourceTableCreateCompanionBuilder,
          $$ContentRemoteResourceTableUpdateCompanionBuilder,
          (
            ContentRemoteResourceData,
            BaseReferences<
              _$AppDb,
              $ContentRemoteResourceTable,
              ContentRemoteResourceData
            >,
          ),
          ContentRemoteResourceData,
          PrefetchHooks Function()
        > {
  $$ContentRemoteResourceTableTableManager(
    _$AppDb db,
    $ContentRemoteResourceTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentRemoteResourceTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ContentRemoteResourceTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ContentRemoteResourceTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> targetNamespace = const Value.absent(),
                Value<String> href = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> objectHash = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> partition = const Value.absent(),
                Value<String> observedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentRemoteResourceCompanion(
                targetNamespace: targetNamespace,
                href: href,
                kind: kind,
                objectHash: objectHash,
                etag: etag,
                partition: partition,
                observedAt: observedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String targetNamespace,
                required String href,
                required String kind,
                Value<String?> objectHash = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> partition = const Value.absent(),
                required String observedAt,
                Value<int> rowid = const Value.absent(),
              }) => ContentRemoteResourceCompanion.insert(
                targetNamespace: targetNamespace,
                href: href,
                kind: kind,
                objectHash: objectHash,
                etag: etag,
                partition: partition,
                observedAt: observedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ContentRemoteResourceTable,
                    ContentRemoteResourceData
                  >(table),
                  BaseReferences<
                    _$AppDb,
                    $ContentRemoteResourceTable,
                    ContentRemoteResourceData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentRemoteResourceTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ContentRemoteResourceTable,
      ContentRemoteResourceData,
      $$ContentRemoteResourceTableFilterComposer,
      $$ContentRemoteResourceTableOrderingComposer,
      $$ContentRemoteResourceTableAnnotationComposer,
      $$ContentRemoteResourceTableCreateCompanionBuilder,
      $$ContentRemoteResourceTableUpdateCompanionBuilder,
      (
        ContentRemoteResourceData,
        BaseReferences<
          _$AppDb,
          $ContentRemoteResourceTable,
          ContentRemoteResourceData
        >,
      ),
      ContentRemoteResourceData,
      PrefetchHooks Function()
    >;
typedef $$ContentRemotePartitionTableCreateCompanionBuilder =
    ContentRemotePartitionCompanion Function({
      required String targetNamespace,
      required String partition,
      Value<String?> syncToken,
      required String scanState,
      Value<String?> scannedAt,
      Value<int> rowid,
    });
typedef $$ContentRemotePartitionTableUpdateCompanionBuilder =
    ContentRemotePartitionCompanion Function({
      Value<String> targetNamespace,
      Value<String> partition,
      Value<String?> syncToken,
      Value<String> scanState,
      Value<String?> scannedAt,
      Value<int> rowid,
    });

class $$ContentRemotePartitionTableFilterComposer
    extends Composer<_$AppDb, $ContentRemotePartitionTable> {
  $$ContentRemotePartitionTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get targetNamespace => $composableBuilder(
    column: $table.targetNamespace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partition => $composableBuilder(
    column: $table.partition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncToken => $composableBuilder(
    column: $table.syncToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanState => $composableBuilder(
    column: $table.scanState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scannedAt => $composableBuilder(
    column: $table.scannedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentRemotePartitionTableOrderingComposer
    extends Composer<_$AppDb, $ContentRemotePartitionTable> {
  $$ContentRemotePartitionTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get targetNamespace => $composableBuilder(
    column: $table.targetNamespace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partition => $composableBuilder(
    column: $table.partition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncToken => $composableBuilder(
    column: $table.syncToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanState => $composableBuilder(
    column: $table.scanState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scannedAt => $composableBuilder(
    column: $table.scannedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentRemotePartitionTableAnnotationComposer
    extends Composer<_$AppDb, $ContentRemotePartitionTable> {
  $$ContentRemotePartitionTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get targetNamespace => $composableBuilder(
    column: $table.targetNamespace,
    builder: (column) => column,
  );

  GeneratedColumn<String> get partition =>
      $composableBuilder(column: $table.partition, builder: (column) => column);

  GeneratedColumn<String> get syncToken =>
      $composableBuilder(column: $table.syncToken, builder: (column) => column);

  GeneratedColumn<String> get scanState =>
      $composableBuilder(column: $table.scanState, builder: (column) => column);

  GeneratedColumn<String> get scannedAt =>
      $composableBuilder(column: $table.scannedAt, builder: (column) => column);
}

class $$ContentRemotePartitionTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ContentRemotePartitionTable,
          ContentRemotePartitionData,
          $$ContentRemotePartitionTableFilterComposer,
          $$ContentRemotePartitionTableOrderingComposer,
          $$ContentRemotePartitionTableAnnotationComposer,
          $$ContentRemotePartitionTableCreateCompanionBuilder,
          $$ContentRemotePartitionTableUpdateCompanionBuilder,
          (
            ContentRemotePartitionData,
            BaseReferences<
              _$AppDb,
              $ContentRemotePartitionTable,
              ContentRemotePartitionData
            >,
          ),
          ContentRemotePartitionData,
          PrefetchHooks Function()
        > {
  $$ContentRemotePartitionTableTableManager(
    _$AppDb db,
    $ContentRemotePartitionTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentRemotePartitionTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ContentRemotePartitionTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ContentRemotePartitionTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> targetNamespace = const Value.absent(),
                Value<String> partition = const Value.absent(),
                Value<String?> syncToken = const Value.absent(),
                Value<String> scanState = const Value.absent(),
                Value<String?> scannedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentRemotePartitionCompanion(
                targetNamespace: targetNamespace,
                partition: partition,
                syncToken: syncToken,
                scanState: scanState,
                scannedAt: scannedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String targetNamespace,
                required String partition,
                Value<String?> syncToken = const Value.absent(),
                required String scanState,
                Value<String?> scannedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentRemotePartitionCompanion.insert(
                targetNamespace: targetNamespace,
                partition: partition,
                syncToken: syncToken,
                scanState: scanState,
                scannedAt: scannedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ContentRemotePartitionTable,
                    ContentRemotePartitionData
                  >(table),
                  BaseReferences<
                    _$AppDb,
                    $ContentRemotePartitionTable,
                    ContentRemotePartitionData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentRemotePartitionTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ContentRemotePartitionTable,
      ContentRemotePartitionData,
      $$ContentRemotePartitionTableFilterComposer,
      $$ContentRemotePartitionTableOrderingComposer,
      $$ContentRemotePartitionTableAnnotationComposer,
      $$ContentRemotePartitionTableCreateCompanionBuilder,
      $$ContentRemotePartitionTableUpdateCompanionBuilder,
      (
        ContentRemotePartitionData,
        BaseReferences<
          _$AppDb,
          $ContentRemotePartitionTable,
          ContentRemotePartitionData
        >,
      ),
      ContentRemotePartitionData,
      PrefetchHooks Function()
    >;
typedef $$ContentManifestTableCreateCompanionBuilder =
    ContentManifestCompanion Function({
      required String targetNamespace,
      required String manifestId,
      required int gid,
      required String representation,
      required String title,
      required String galleryUrl,
      required String portableJson,
      required String importedAt,
      Value<int> rowid,
    });
typedef $$ContentManifestTableUpdateCompanionBuilder =
    ContentManifestCompanion Function({
      Value<String> targetNamespace,
      Value<String> manifestId,
      Value<int> gid,
      Value<String> representation,
      Value<String> title,
      Value<String> galleryUrl,
      Value<String> portableJson,
      Value<String> importedAt,
      Value<int> rowid,
    });

class $$ContentManifestTableFilterComposer
    extends Composer<_$AppDb, $ContentManifestTable> {
  $$ContentManifestTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get targetNamespace => $composableBuilder(
    column: $table.targetNamespace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestId => $composableBuilder(
    column: $table.manifestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gid => $composableBuilder(
    column: $table.gid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get representation => $composableBuilder(
    column: $table.representation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get galleryUrl => $composableBuilder(
    column: $table.galleryUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get portableJson => $composableBuilder(
    column: $table.portableJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentManifestTableOrderingComposer
    extends Composer<_$AppDb, $ContentManifestTable> {
  $$ContentManifestTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get targetNamespace => $composableBuilder(
    column: $table.targetNamespace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestId => $composableBuilder(
    column: $table.manifestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gid => $composableBuilder(
    column: $table.gid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get representation => $composableBuilder(
    column: $table.representation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get galleryUrl => $composableBuilder(
    column: $table.galleryUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get portableJson => $composableBuilder(
    column: $table.portableJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentManifestTableAnnotationComposer
    extends Composer<_$AppDb, $ContentManifestTable> {
  $$ContentManifestTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get targetNamespace => $composableBuilder(
    column: $table.targetNamespace,
    builder: (column) => column,
  );

  GeneratedColumn<String> get manifestId => $composableBuilder(
    column: $table.manifestId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gid =>
      $composableBuilder(column: $table.gid, builder: (column) => column);

  GeneratedColumn<String> get representation => $composableBuilder(
    column: $table.representation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get galleryUrl => $composableBuilder(
    column: $table.galleryUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get portableJson => $composableBuilder(
    column: $table.portableJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );
}

class $$ContentManifestTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ContentManifestTable,
          ContentManifestData,
          $$ContentManifestTableFilterComposer,
          $$ContentManifestTableOrderingComposer,
          $$ContentManifestTableAnnotationComposer,
          $$ContentManifestTableCreateCompanionBuilder,
          $$ContentManifestTableUpdateCompanionBuilder,
          (
            ContentManifestData,
            BaseReferences<_$AppDb, $ContentManifestTable, ContentManifestData>,
          ),
          ContentManifestData,
          PrefetchHooks Function()
        > {
  $$ContentManifestTableTableManager(_$AppDb db, $ContentManifestTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentManifestTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentManifestTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentManifestTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> targetNamespace = const Value.absent(),
                Value<String> manifestId = const Value.absent(),
                Value<int> gid = const Value.absent(),
                Value<String> representation = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> galleryUrl = const Value.absent(),
                Value<String> portableJson = const Value.absent(),
                Value<String> importedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentManifestCompanion(
                targetNamespace: targetNamespace,
                manifestId: manifestId,
                gid: gid,
                representation: representation,
                title: title,
                galleryUrl: galleryUrl,
                portableJson: portableJson,
                importedAt: importedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String targetNamespace,
                required String manifestId,
                required int gid,
                required String representation,
                required String title,
                required String galleryUrl,
                required String portableJson,
                required String importedAt,
                Value<int> rowid = const Value.absent(),
              }) => ContentManifestCompanion.insert(
                targetNamespace: targetNamespace,
                manifestId: manifestId,
                gid: gid,
                representation: representation,
                title: title,
                galleryUrl: galleryUrl,
                portableJson: portableJson,
                importedAt: importedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContentManifestTable, ContentManifestData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDb,
                    $ContentManifestTable,
                    ContentManifestData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentManifestTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ContentManifestTable,
      ContentManifestData,
      $$ContentManifestTableFilterComposer,
      $$ContentManifestTableOrderingComposer,
      $$ContentManifestTableAnnotationComposer,
      $$ContentManifestTableCreateCompanionBuilder,
      $$ContentManifestTableUpdateCompanionBuilder,
      (
        ContentManifestData,
        BaseReferences<_$AppDb, $ContentManifestTable, ContentManifestData>,
      ),
      ContentManifestData,
      PrefetchHooks Function()
    >;
typedef $$ContentObjectRepresentationTableCreateCompanionBuilder =
    ContentObjectRepresentationCompanion Function({
      required String targetNamespace,
      required String rawHash,
      required String objectHash,
      required String codecProfile,
      required int storedLength,
      Value<int> rowid,
    });
typedef $$ContentObjectRepresentationTableUpdateCompanionBuilder =
    ContentObjectRepresentationCompanion Function({
      Value<String> targetNamespace,
      Value<String> rawHash,
      Value<String> objectHash,
      Value<String> codecProfile,
      Value<int> storedLength,
      Value<int> rowid,
    });

class $$ContentObjectRepresentationTableFilterComposer
    extends Composer<_$AppDb, $ContentObjectRepresentationTable> {
  $$ContentObjectRepresentationTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get targetNamespace => $composableBuilder(
    column: $table.targetNamespace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawHash => $composableBuilder(
    column: $table.rawHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objectHash => $composableBuilder(
    column: $table.objectHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get codecProfile => $composableBuilder(
    column: $table.codecProfile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storedLength => $composableBuilder(
    column: $table.storedLength,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentObjectRepresentationTableOrderingComposer
    extends Composer<_$AppDb, $ContentObjectRepresentationTable> {
  $$ContentObjectRepresentationTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get targetNamespace => $composableBuilder(
    column: $table.targetNamespace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawHash => $composableBuilder(
    column: $table.rawHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objectHash => $composableBuilder(
    column: $table.objectHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get codecProfile => $composableBuilder(
    column: $table.codecProfile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storedLength => $composableBuilder(
    column: $table.storedLength,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentObjectRepresentationTableAnnotationComposer
    extends Composer<_$AppDb, $ContentObjectRepresentationTable> {
  $$ContentObjectRepresentationTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get targetNamespace => $composableBuilder(
    column: $table.targetNamespace,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawHash =>
      $composableBuilder(column: $table.rawHash, builder: (column) => column);

  GeneratedColumn<String> get objectHash => $composableBuilder(
    column: $table.objectHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get codecProfile => $composableBuilder(
    column: $table.codecProfile,
    builder: (column) => column,
  );

  GeneratedColumn<int> get storedLength => $composableBuilder(
    column: $table.storedLength,
    builder: (column) => column,
  );
}

class $$ContentObjectRepresentationTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ContentObjectRepresentationTable,
          ContentObjectRepresentationData,
          $$ContentObjectRepresentationTableFilterComposer,
          $$ContentObjectRepresentationTableOrderingComposer,
          $$ContentObjectRepresentationTableAnnotationComposer,
          $$ContentObjectRepresentationTableCreateCompanionBuilder,
          $$ContentObjectRepresentationTableUpdateCompanionBuilder,
          (
            ContentObjectRepresentationData,
            BaseReferences<
              _$AppDb,
              $ContentObjectRepresentationTable,
              ContentObjectRepresentationData
            >,
          ),
          ContentObjectRepresentationData,
          PrefetchHooks Function()
        > {
  $$ContentObjectRepresentationTableTableManager(
    _$AppDb db,
    $ContentObjectRepresentationTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentObjectRepresentationTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ContentObjectRepresentationTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ContentObjectRepresentationTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> targetNamespace = const Value.absent(),
                Value<String> rawHash = const Value.absent(),
                Value<String> objectHash = const Value.absent(),
                Value<String> codecProfile = const Value.absent(),
                Value<int> storedLength = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentObjectRepresentationCompanion(
                targetNamespace: targetNamespace,
                rawHash: rawHash,
                objectHash: objectHash,
                codecProfile: codecProfile,
                storedLength: storedLength,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String targetNamespace,
                required String rawHash,
                required String objectHash,
                required String codecProfile,
                required int storedLength,
                Value<int> rowid = const Value.absent(),
              }) => ContentObjectRepresentationCompanion.insert(
                targetNamespace: targetNamespace,
                rawHash: rawHash,
                objectHash: objectHash,
                codecProfile: codecProfile,
                storedLength: storedLength,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ContentObjectRepresentationTable,
                    ContentObjectRepresentationData
                  >(table),
                  BaseReferences<
                    _$AppDb,
                    $ContentObjectRepresentationTable,
                    ContentObjectRepresentationData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentObjectRepresentationTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ContentObjectRepresentationTable,
      ContentObjectRepresentationData,
      $$ContentObjectRepresentationTableFilterComposer,
      $$ContentObjectRepresentationTableOrderingComposer,
      $$ContentObjectRepresentationTableAnnotationComposer,
      $$ContentObjectRepresentationTableCreateCompanionBuilder,
      $$ContentObjectRepresentationTableUpdateCompanionBuilder,
      (
        ContentObjectRepresentationData,
        BaseReferences<
          _$AppDb,
          $ContentObjectRepresentationTable,
          ContentObjectRepresentationData
        >,
      ),
      ContentObjectRepresentationData,
      PrefetchHooks Function()
    >;
typedef $$ContentWorkItemTableCreateCompanionBuilder =
    ContentWorkItemCompanion Function({
      required String workItemId,
      required String targetNamespace,
      Value<String?> copyId,
      required String kind,
      required String state,
      Value<String?> inputManifestId,
      required String inputJson,
      Value<String?> localArtifactPath,
      Value<String?> remoteDestination,
      Value<String> artifactsJson,
      Value<String> committedObjectsJson,
      Value<String?> pendingManifestId,
      Value<String> source,
      Value<String> finishAction,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$ContentWorkItemTableUpdateCompanionBuilder =
    ContentWorkItemCompanion Function({
      Value<String> workItemId,
      Value<String> targetNamespace,
      Value<String?> copyId,
      Value<String> kind,
      Value<String> state,
      Value<String?> inputManifestId,
      Value<String> inputJson,
      Value<String?> localArtifactPath,
      Value<String?> remoteDestination,
      Value<String> artifactsJson,
      Value<String> committedObjectsJson,
      Value<String?> pendingManifestId,
      Value<String> source,
      Value<String> finishAction,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$ContentWorkItemTableFilterComposer
    extends Composer<_$AppDb, $ContentWorkItemTable> {
  $$ContentWorkItemTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get workItemId => $composableBuilder(
    column: $table.workItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetNamespace => $composableBuilder(
    column: $table.targetNamespace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get copyId => $composableBuilder(
    column: $table.copyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputManifestId => $composableBuilder(
    column: $table.inputManifestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputJson => $composableBuilder(
    column: $table.inputJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localArtifactPath => $composableBuilder(
    column: $table.localArtifactPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteDestination => $composableBuilder(
    column: $table.remoteDestination,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artifactsJson => $composableBuilder(
    column: $table.artifactsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get committedObjectsJson => $composableBuilder(
    column: $table.committedObjectsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pendingManifestId => $composableBuilder(
    column: $table.pendingManifestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finishAction => $composableBuilder(
    column: $table.finishAction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentWorkItemTableOrderingComposer
    extends Composer<_$AppDb, $ContentWorkItemTable> {
  $$ContentWorkItemTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get workItemId => $composableBuilder(
    column: $table.workItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetNamespace => $composableBuilder(
    column: $table.targetNamespace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get copyId => $composableBuilder(
    column: $table.copyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputManifestId => $composableBuilder(
    column: $table.inputManifestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputJson => $composableBuilder(
    column: $table.inputJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localArtifactPath => $composableBuilder(
    column: $table.localArtifactPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteDestination => $composableBuilder(
    column: $table.remoteDestination,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artifactsJson => $composableBuilder(
    column: $table.artifactsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get committedObjectsJson => $composableBuilder(
    column: $table.committedObjectsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingManifestId => $composableBuilder(
    column: $table.pendingManifestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finishAction => $composableBuilder(
    column: $table.finishAction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentWorkItemTableAnnotationComposer
    extends Composer<_$AppDb, $ContentWorkItemTable> {
  $$ContentWorkItemTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get workItemId => $composableBuilder(
    column: $table.workItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetNamespace => $composableBuilder(
    column: $table.targetNamespace,
    builder: (column) => column,
  );

  GeneratedColumn<String> get copyId =>
      $composableBuilder(column: $table.copyId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get inputManifestId => $composableBuilder(
    column: $table.inputManifestId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inputJson =>
      $composableBuilder(column: $table.inputJson, builder: (column) => column);

  GeneratedColumn<String> get localArtifactPath => $composableBuilder(
    column: $table.localArtifactPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteDestination => $composableBuilder(
    column: $table.remoteDestination,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artifactsJson => $composableBuilder(
    column: $table.artifactsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get committedObjectsJson => $composableBuilder(
    column: $table.committedObjectsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pendingManifestId => $composableBuilder(
    column: $table.pendingManifestId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get finishAction => $composableBuilder(
    column: $table.finishAction,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ContentWorkItemTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ContentWorkItemTable,
          ContentWorkItemData,
          $$ContentWorkItemTableFilterComposer,
          $$ContentWorkItemTableOrderingComposer,
          $$ContentWorkItemTableAnnotationComposer,
          $$ContentWorkItemTableCreateCompanionBuilder,
          $$ContentWorkItemTableUpdateCompanionBuilder,
          (
            ContentWorkItemData,
            BaseReferences<_$AppDb, $ContentWorkItemTable, ContentWorkItemData>,
          ),
          ContentWorkItemData,
          PrefetchHooks Function()
        > {
  $$ContentWorkItemTableTableManager(_$AppDb db, $ContentWorkItemTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentWorkItemTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentWorkItemTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentWorkItemTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> workItemId = const Value.absent(),
                Value<String> targetNamespace = const Value.absent(),
                Value<String?> copyId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> inputManifestId = const Value.absent(),
                Value<String> inputJson = const Value.absent(),
                Value<String?> localArtifactPath = const Value.absent(),
                Value<String?> remoteDestination = const Value.absent(),
                Value<String> artifactsJson = const Value.absent(),
                Value<String> committedObjectsJson = const Value.absent(),
                Value<String?> pendingManifestId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> finishAction = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentWorkItemCompanion(
                workItemId: workItemId,
                targetNamespace: targetNamespace,
                copyId: copyId,
                kind: kind,
                state: state,
                inputManifestId: inputManifestId,
                inputJson: inputJson,
                localArtifactPath: localArtifactPath,
                remoteDestination: remoteDestination,
                artifactsJson: artifactsJson,
                committedObjectsJson: committedObjectsJson,
                pendingManifestId: pendingManifestId,
                source: source,
                finishAction: finishAction,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String workItemId,
                required String targetNamespace,
                Value<String?> copyId = const Value.absent(),
                required String kind,
                required String state,
                Value<String?> inputManifestId = const Value.absent(),
                required String inputJson,
                Value<String?> localArtifactPath = const Value.absent(),
                Value<String?> remoteDestination = const Value.absent(),
                Value<String> artifactsJson = const Value.absent(),
                Value<String> committedObjectsJson = const Value.absent(),
                Value<String?> pendingManifestId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> finishAction = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ContentWorkItemCompanion.insert(
                workItemId: workItemId,
                targetNamespace: targetNamespace,
                copyId: copyId,
                kind: kind,
                state: state,
                inputManifestId: inputManifestId,
                inputJson: inputJson,
                localArtifactPath: localArtifactPath,
                remoteDestination: remoteDestination,
                artifactsJson: artifactsJson,
                committedObjectsJson: committedObjectsJson,
                pendingManifestId: pendingManifestId,
                source: source,
                finishAction: finishAction,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContentWorkItemTable, ContentWorkItemData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDb,
                    $ContentWorkItemTable,
                    ContentWorkItemData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentWorkItemTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ContentWorkItemTable,
      ContentWorkItemData,
      $$ContentWorkItemTableFilterComposer,
      $$ContentWorkItemTableOrderingComposer,
      $$ContentWorkItemTableAnnotationComposer,
      $$ContentWorkItemTableCreateCompanionBuilder,
      $$ContentWorkItemTableUpdateCompanionBuilder,
      (
        ContentWorkItemData,
        BaseReferences<_$AppDb, $ContentWorkItemTable, ContentWorkItemData>,
      ),
      ContentWorkItemData,
      PrefetchHooks Function()
    >;
typedef $$ContentPageReplacementTableCreateCompanionBuilder =
    ContentPageReplacementCompanion Function({
      required String replacementId,
      required String copyId,
      required int ordinal,
      required int queueOrder,
      required String state,
      required String oldPath,
      required String newPath,
      required String tempPath,
      required String retainedPath,
      Value<String?> newMetadataJson,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$ContentPageReplacementTableUpdateCompanionBuilder =
    ContentPageReplacementCompanion Function({
      Value<String> replacementId,
      Value<String> copyId,
      Value<int> ordinal,
      Value<int> queueOrder,
      Value<String> state,
      Value<String> oldPath,
      Value<String> newPath,
      Value<String> tempPath,
      Value<String> retainedPath,
      Value<String?> newMetadataJson,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$ContentPageReplacementTableFilterComposer
    extends Composer<_$AppDb, $ContentPageReplacementTable> {
  $$ContentPageReplacementTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get replacementId => $composableBuilder(
    column: $table.replacementId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get copyId => $composableBuilder(
    column: $table.copyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get queueOrder => $composableBuilder(
    column: $table.queueOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oldPath => $composableBuilder(
    column: $table.oldPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get newPath => $composableBuilder(
    column: $table.newPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tempPath => $composableBuilder(
    column: $table.tempPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get retainedPath => $composableBuilder(
    column: $table.retainedPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get newMetadataJson => $composableBuilder(
    column: $table.newMetadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentPageReplacementTableOrderingComposer
    extends Composer<_$AppDb, $ContentPageReplacementTable> {
  $$ContentPageReplacementTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get replacementId => $composableBuilder(
    column: $table.replacementId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get copyId => $composableBuilder(
    column: $table.copyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get queueOrder => $composableBuilder(
    column: $table.queueOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oldPath => $composableBuilder(
    column: $table.oldPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newPath => $composableBuilder(
    column: $table.newPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tempPath => $composableBuilder(
    column: $table.tempPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get retainedPath => $composableBuilder(
    column: $table.retainedPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newMetadataJson => $composableBuilder(
    column: $table.newMetadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentPageReplacementTableAnnotationComposer
    extends Composer<_$AppDb, $ContentPageReplacementTable> {
  $$ContentPageReplacementTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get replacementId => $composableBuilder(
    column: $table.replacementId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get copyId =>
      $composableBuilder(column: $table.copyId, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<int> get queueOrder => $composableBuilder(
    column: $table.queueOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get oldPath =>
      $composableBuilder(column: $table.oldPath, builder: (column) => column);

  GeneratedColumn<String> get newPath =>
      $composableBuilder(column: $table.newPath, builder: (column) => column);

  GeneratedColumn<String> get tempPath =>
      $composableBuilder(column: $table.tempPath, builder: (column) => column);

  GeneratedColumn<String> get retainedPath => $composableBuilder(
    column: $table.retainedPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get newMetadataJson => $composableBuilder(
    column: $table.newMetadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ContentPageReplacementTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ContentPageReplacementTable,
          ContentPageReplacementData,
          $$ContentPageReplacementTableFilterComposer,
          $$ContentPageReplacementTableOrderingComposer,
          $$ContentPageReplacementTableAnnotationComposer,
          $$ContentPageReplacementTableCreateCompanionBuilder,
          $$ContentPageReplacementTableUpdateCompanionBuilder,
          (
            ContentPageReplacementData,
            BaseReferences<
              _$AppDb,
              $ContentPageReplacementTable,
              ContentPageReplacementData
            >,
          ),
          ContentPageReplacementData,
          PrefetchHooks Function()
        > {
  $$ContentPageReplacementTableTableManager(
    _$AppDb db,
    $ContentPageReplacementTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentPageReplacementTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ContentPageReplacementTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ContentPageReplacementTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> replacementId = const Value.absent(),
                Value<String> copyId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<int> queueOrder = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String> oldPath = const Value.absent(),
                Value<String> newPath = const Value.absent(),
                Value<String> tempPath = const Value.absent(),
                Value<String> retainedPath = const Value.absent(),
                Value<String?> newMetadataJson = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentPageReplacementCompanion(
                replacementId: replacementId,
                copyId: copyId,
                ordinal: ordinal,
                queueOrder: queueOrder,
                state: state,
                oldPath: oldPath,
                newPath: newPath,
                tempPath: tempPath,
                retainedPath: retainedPath,
                newMetadataJson: newMetadataJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String replacementId,
                required String copyId,
                required int ordinal,
                required int queueOrder,
                required String state,
                required String oldPath,
                required String newPath,
                required String tempPath,
                required String retainedPath,
                Value<String?> newMetadataJson = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ContentPageReplacementCompanion.insert(
                replacementId: replacementId,
                copyId: copyId,
                ordinal: ordinal,
                queueOrder: queueOrder,
                state: state,
                oldPath: oldPath,
                newPath: newPath,
                tempPath: tempPath,
                retainedPath: retainedPath,
                newMetadataJson: newMetadataJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ContentPageReplacementTable,
                    ContentPageReplacementData
                  >(table),
                  BaseReferences<
                    _$AppDb,
                    $ContentPageReplacementTable,
                    ContentPageReplacementData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentPageReplacementTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ContentPageReplacementTable,
      ContentPageReplacementData,
      $$ContentPageReplacementTableFilterComposer,
      $$ContentPageReplacementTableOrderingComposer,
      $$ContentPageReplacementTableAnnotationComposer,
      $$ContentPageReplacementTableCreateCompanionBuilder,
      $$ContentPageReplacementTableUpdateCompanionBuilder,
      (
        ContentPageReplacementData,
        BaseReferences<
          _$AppDb,
          $ContentPageReplacementTable,
          ContentPageReplacementData
        >,
      ),
      ContentPageReplacementData,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$TagTableTableManager get tag => $$TagTableTableManager(_db, _db.tag);
  $$ContentCopyTableTableManager get contentCopy =>
      $$ContentCopyTableTableManager(_db, _db.contentCopy);
  $$ArchiveDownloadedTableTableManager get archiveDownloaded =>
      $$ArchiveDownloadedTableTableManager(_db, _db.archiveDownloaded);
  $$ArchiveGroupTableTableManager get archiveGroup =>
      $$ArchiveGroupTableTableManager(_db, _db.archiveGroup);
  $$GalleryDownloadedTableTableManager get galleryDownloaded =>
      $$GalleryDownloadedTableTableManager(_db, _db.galleryDownloaded);
  $$GalleryGroupTableTableManager get galleryGroup =>
      $$GalleryGroupTableTableManager(_db, _db.galleryGroup);
  $$ImageTableTableManager get image =>
      $$ImageTableTableManager(_db, _db.image);
  $$GalleryHistoryV2TableTableManager get galleryHistoryV2 =>
      $$GalleryHistoryV2TableTableManager(_db, _db.galleryHistoryV2);
  $$TagCountTableTableManager get tagCount =>
      $$TagCountTableTableManager(_db, _db.tagCount);
  $$DioCacheTableTableManager get dioCache =>
      $$DioCacheTableTableManager(_db, _db.dioCache);
  $$BlockRuleTableTableManager get blockRule =>
      $$BlockRuleTableTableManager(_db, _db.blockRule);
  $$LocalConfigTableTableManager get localConfig =>
      $$LocalConfigTableTableManager(_db, _db.localConfig);
  $$ContentPageTableTableManager get contentPage =>
      $$ContentPageTableTableManager(_db, _db.contentPage);
  $$ContentRemoteResourceTableTableManager get contentRemoteResource =>
      $$ContentRemoteResourceTableTableManager(_db, _db.contentRemoteResource);
  $$ContentRemotePartitionTableTableManager get contentRemotePartition =>
      $$ContentRemotePartitionTableTableManager(
        _db,
        _db.contentRemotePartition,
      );
  $$ContentManifestTableTableManager get contentManifest =>
      $$ContentManifestTableTableManager(_db, _db.contentManifest);
  $$ContentObjectRepresentationTableTableManager
  get contentObjectRepresentation =>
      $$ContentObjectRepresentationTableTableManager(
        _db,
        _db.contentObjectRepresentation,
      );
  $$ContentWorkItemTableTableManager get contentWorkItem =>
      $$ContentWorkItemTableTableManager(_db, _db.contentWorkItem);
  $$ContentPageReplacementTableTableManager get contentPageReplacement =>
      $$ContentPageReplacementTableTableManager(
        _db,
        _db.contentPageReplacement,
      );
}
