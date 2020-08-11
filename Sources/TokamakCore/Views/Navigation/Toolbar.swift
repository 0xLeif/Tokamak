// Copyright 2020 Tokamak contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//  Created by Carson Katri on 7/7/20.
//

struct ToolbarKey: PreferenceKey {
  static let defaultValue = ToolbarValue(EmptyView())
  static func reduce(value: inout ToolbarValue, nextValue: () -> ToolbarValue) {
    value = nextValue()
  }

  final class ToolbarValue: Equatable {
    let content: AnyView
    init<V>(_ view: V) where V: View {
      content = AnyView(view)
    }

    static func == (lhs: ToolbarValue, rhs: ToolbarValue) -> Bool {
      lhs === rhs
    }
  }
}

public struct ToolbarItemGroup<ID, Items> {
  let items: Items
  let _items: [AnyView]
}

public struct _ToolbarItemGroupProxy<ID, Items> {
  public let subject: ToolbarItemGroup<ID, Items>

  public init(_ subject: ToolbarItemGroup<ID, Items>) { self.subject = subject }

  public var items: Items { subject.items }
  public var _items: [AnyView] { subject._items }
}

public struct ToolbarItemPlacement: Equatable {
  let rawValue: Int8
  public static let automatic: ToolbarItemPlacement = .init(rawValue: 1 << 0)
  public static let principal: ToolbarItemPlacement = .init(rawValue: 1 << 1)
  public static let navigation: ToolbarItemPlacement = .init(rawValue: 1 << 2)
  public static let primaryAction: ToolbarItemPlacement = .init(rawValue: 1 << 3)
  public static let status: ToolbarItemPlacement = .init(rawValue: 1 << 4)
  public static let confirmationAction: ToolbarItemPlacement = .init(rawValue: 1 << 5)
  public static let cancellationAction: ToolbarItemPlacement = .init(rawValue: 1 << 6)
  public static let destructiveAction: ToolbarItemPlacement = .init(rawValue: 1 << 7)
  public static let navigationBarLeading: ToolbarItemPlacement = .init(rawValue: 1 << 8)
  public static let navigationBarTrailing: ToolbarItemPlacement = .init(rawValue: 1 << 9)
  public static let bottomBar: ToolbarItemPlacement = .init(rawValue: 1 << 10)
}

public protocol AnyToolbarItem {
  var placement: ToolbarItemPlacement { get }
  var anyContent: AnyView { get }
}

public struct ToolbarItem<ID, Content>: View, AnyToolbarItem where Content: View {
  public let id: ID
  public let placement: ToolbarItemPlacement
  let showsByDefault: Bool
  let content: Content
  public var anyContent: AnyView { AnyView(content) }
  public init(id: ID,
              placement: ToolbarItemPlacement = .automatic,
              showsByDefault: Bool = true,
              @ViewBuilder content: () -> Content)
  {
    self.id = id
    self.placement = placement
    self.showsByDefault = showsByDefault
    self.content = content()
  }

  public var body: Content {
    content
  }
}

extension ToolbarItem where ID == () {
  public init(placement: ToolbarItemPlacement = .automatic,
              @ViewBuilder content: () -> Content)
  {
    self.init(id: (), placement: placement, showsByDefault: true, content: content)
  }
}

extension ToolbarItem: Identifiable where ID: Hashable {}

/// This is a helper class that works around absence of "package private" access control in Swift
public struct _ToolbarItemProxy<ID, Content> where Content: View {
  public let subject: ToolbarItem<ID, Content>

  public init(_ subject: ToolbarItem<ID, Content>) { self.subject = subject }

  public var placement: ToolbarItemPlacement { subject.placement }
  public var showsByDefault: Bool { subject.showsByDefault }
  public var content: Content { subject.content }
}

public protocol _AnyToolbarContainer {
  var anyContent: AnyView { get }
}

public protocol ToolbarDeferredToRenderer {
  var deferredToolbar: AnyView { get }
}

public struct _ToolbarContainer<ID, Content, Wrapped>: View where Wrapped: View {
  @EnvironmentObject var navigationContext: NavigationContext
  @State private var navigationTitle: String?

  init(id: ID, content: Content, child: Wrapped) {
    (self.id, self.content, self.child) = (id, content, child)
  }

  public let id: ID
  public let content: Content
  public let child: Wrapped

  public var body: some View {
    let bar: AnyView
    if let deferredBar = self as? ToolbarDeferredToRenderer {
      bar = deferredBar.deferredToolbar
    } else {
      bar = AnyView(EmptyView())
    }
    return child
      .transformPreference(ToolbarKey.self) {
        $0 = ToolbarKey.ToolbarValue(bar)
      }
      .onPreferenceChange(NavigationTitleKey.self) {
        navigationTitle = $0
      }
  }

  @ViewBuilder
  public var title: some View {
    if let text = navigationTitle {
      Text(text)
    }
  }
}

extension _ToolbarContainer: _AnyToolbarContainer where Content: View {
  public var anyContent: AnyView { AnyView(content) }
}

extension View {
  @_disfavoredOverload
  public func toolbar<Content>(@ViewBuilder content: () -> Content)
    -> some View where Content: View
  {
    _ToolbarContainer(id: (), content: content(), child: self)
  }

  public func toolbar<Items>(@ToolbarContentBuilder <()> items: () -> ToolbarItemGroup<(), Items>)
    -> some View
  {
    _ToolbarContainer(id: (), content: items(), child: self)
  }

  public func toolbar<Items>(
    id: String,
    @ToolbarContentBuilder <String> items: () -> ToolbarItemGroup<String, Items>
  ) -> some View {
    _ToolbarContainer(id: id, content: items(), child: self)
  }
}
