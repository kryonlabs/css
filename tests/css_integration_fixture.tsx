// TSX composition fixture for the CSS behavior tests. Every widget
// composition operation runs through Kryon's public TSX components here;
// the native tests keep their state, policy and assertions, and read mid-
// composition results through the records this fixture fills.
import * as NativeBox from "kryon/box";
import * as NativeButton from "kryon/button";
import * as NativeGrid from "kryon/grid_props";
import * as NativeLayout from "kryon/layout";
import * as NativePage from "kryon/page";
import * as NativeText from "kryon/text";
import { Rectangle } from "kryon/geometry";
import { PendingPaintCount } from "kryon/paint_queue";
import { Session } from "kryon/session";
import { StyleData } from "kryon/style";
import { StyleClass } from "css_export";
import { Scoped } from "std/callable";
import { TreeSubmittedBounds, TreeSubmittedCount } from "kryon/tree";
import { Box } from "kryon/tsx/box";
import { Button } from "kryon/tsx/button";
import { MeasuredGrid } from "kryon/tsx/grid";
import { Column, MeasuredRow, Row, StyledBox } from "kryon/tsx/layout";
import { Section } from "kryon/tsx/page";
import { Text } from "kryon/tsx/text";
import * as Support from "css_test_support";

export interface SizingResults {
    column: NativeLayout.LayoutContainer;
    node: s32;
}

export interface ContextResults {
    panel: NativeLayout.LayoutContainer;
    inner: NativeLayout.LayoutContainer;
}

export interface BoxResults {
    page: NativeLayout.LayoutContainer;
    inset: NativeLayout.LayoutContainer;
    child: s32;
    after: s32;
    bounded: NativeLayout.LayoutContainer;
    fluid: NativeLayout.LayoutContainer;
}

export interface PaintResults {
    before: s32;
    card: NativeLayout.LayoutContainer;
}

export interface FillResults {
    side: NativeLayout.LayoutContainer;
    main: NativeLayout.LayoutContainer;
    title: Rectangle;
    grow: NativeLayout.LayoutContainer;
    row: NativeLayout.LayoutContainer;
    push: NativeLayout.LayoutContainer;
}

export interface PercentResults {
    half: NativeLayout.LayoutContainer;
    limited: NativeLayout.LayoutContainer;
    loose: NativeLayout.LayoutContainer;
    tall: NativeLayout.LayoutContainer;
    share: NativeLayout.LayoutContainer;
    basis: NativeLayout.LayoutContainer;
}

export function DrawButton(session: Session, props: NativeButton.Props): boolean {
    return <Button session={session} props={props}/>;
}

export function OpenRow(session: Session, props: NativeLayout.Props): NativeLayout.LayoutContainer {
    return Row({session: session, props: props, children: (): void => {}});
}

export function OpenColumn(session: Session, props: NativeLayout.Props): NativeLayout.LayoutContainer {
    return Column({session: session, props: props, children: (): void => {}});
}

export interface DashboardResults {
    opened: boolean;
    grid: NativeLayout.GridResult;
    metrics: NativeLayout.GridResult;
}

export function Dashboard(session: Session, section: boolean, page: NativePage.SectionProps,
        column: NativeLayout.Props, panels: NativeGrid.GridProps, metrics: NativeGrid.GridProps,
        items: NativeGrid.GridItem[], metricItems: NativeGrid.GridItem[], emptyBounds: Rectangle[],
        results: DashboardResults[]): void {
    let opened = false;
    {
        const children: Scoped<() => void> = (): void => {
            results[s32(0)].grid = MeasuredGrid({session: session, props: panels, items: items,
                itemBounds: emptyBounds, children: (_grid: NativeLayout.GridResult): void => {}});
            results[s32(0)].metrics = MeasuredGrid({session: session, props: metrics, items: metricItems,
                itemBounds: emptyBounds, children: (_grid: NativeLayout.GridResult): void => {}});
        };
        if (section) {
            opened = Section({session: session, props: page, children: (): void => { children(); }}).opened;
        } else {
            opened = Column({session: session, props: column, children: (): void => { children(); }}).opened;
        }
    }
    results[s32(0)].opened = opened;
}

export function FlexRow(session: Session, props: NativeLayout.Props, items: NativeLayout.FlexItem[],
        placed: NativeLayout.FlexPlacement[]): NativeLayout.LayoutContainer {
    return MeasuredRow({session: session, props: props, items: items, placements: placed,
        children: (_container: NativeLayout.LayoutContainer): void => {}});
}

export function SizingRow(session: Session, props: NativeLayout.Props, column: NativeLayout.Props,
        sibling: NativeBox.Props, results: SizingResults[]): NativeLayout.LayoutContainer {
    return Row({session: session, props: props, children: (): void => {
        results[s32(0)].column = Column({session: session, props: column, children: (): void => {}});
        results[s32(0)].node = Box({session: session, props: sibling});
    }});
}

export function BoxBody(session: Session, outer: NativeLayout.Props, page: NativeLayout.Props,
        inset: NativeLayout.Props, child: NativeBox.Props, after: NativeBox.Props,
        bounded: NativeLayout.Props, fluid: NativeLayout.Props,
        results: BoxResults[]): NativeLayout.LayoutContainer {
    return Column({session: session, props: outer, children: (): void => {
        results[s32(0)].page = Column({session: session, props: page, children: (): void => {}});
        results[s32(0)].inset = Column({session: session, props: inset, children: (): void => {
            results[s32(0)].child = Box({session: session, props: child});
        }});
        results[s32(0)].after = Box({session: session, props: after});
        results[s32(0)].bounded = Row({session: session, props: bounded, children: (): void => {}});
        results[s32(0)].fluid = Column({session: session, props: fluid, children: (): void => {}});
    }});
}

export function CardWithChild(session: Session, outer: NativeLayout.Props, card: NativeLayout.Props,
        child: NativeBox.Props, results: PaintResults[]): NativeLayout.LayoutContainer {
    return Column({session: session, props: outer, children: (): void => {
        results[s32(0)].before = PendingPaintCount(session);
        results[s32(0)].card = Column({session: session, props: card, children: (): void => {
            Box({session: session, props: child});
        }});
    }});
}

export function FillBody(session: Session, shell: NativeLayout.Props, side: NativeLayout.Props,
        main: NativeLayout.Props, text: NativeText.Props, grow: NativeLayout.Props,
        row: NativeLayout.Props, push: NativeLayout.Props,
        results: FillResults[]): NativeLayout.LayoutContainer {
    return Row({session: session, props: shell, children: (): void => {
        results[s32(0)].side = Column({session: session, props: side, children: (): void => {}});
        results[s32(0)].main = Column({session: session, props: main, children: (): void => {
            Text({session: session, props: text});
            results[s32(0)].title = TreeSubmittedBounds(session, TreeSubmittedCount(session) - s32(1));
            results[s32(0)].grow = Column({session: session, props: grow, children: (): void => {}});
            results[s32(0)].row = Row({session: session, props: row, children: (): void => {
                results[s32(0)].push = Row({session: session, props: push, children: (): void => {}});
            }});
        }});
    }});
}

export function PercentBody(session: Session, shell: NativeLayout.Props, half: NativeLayout.Props,
        limited: NativeLayout.Props, loose: NativeLayout.Props, tall: NativeLayout.Props,
        child: NativeBox.Props, share: NativeLayout.Props, basis: NativeLayout.Props,
        items: NativeLayout.FlexItem[], placed: NativeLayout.FlexPlacement[],
        results: PercentResults[]): NativeLayout.LayoutContainer {
    const container = Column({session: session, props: shell, children: (): void => {
        results[s32(0)].half = Column({session: session, props: half, children: (): void => {}});
        results[s32(0)].limited = Column({session: session, props: limited, children: (): void => {}});
        results[s32(0)].loose = Column({session: session, props: loose, children: (): void => {
            results[s32(0)].tall = Column({session: session, props: tall, children: (): void => {
                Box({session: session, props: child});
            }});
        }});
        results[s32(0)].share = Row({session: session, props: share, children: (): void => {}});
    }});
    results[s32(0)].basis = MeasuredRow({session: session, props: basis, items: items, placements: placed,
        children: (_container: NativeLayout.LayoutContainer): void => {}});
    return container;
}

export function ContextBody(session: Session, outer: NativeLayout.Props, panel: NativeLayout.Props,
        sibling: NativeBox.Props, inner: NativeLayout.Props,
        results: ContextResults[]): NativeLayout.LayoutContainer {
    return Column({session: session, props: outer, children: (): void => {
        Support.CheckContextStage(s32(0));
        results[s32(0)].panel = Column({session: session, props: panel, children: (): void => {
            Support.CheckContextStage(s32(1));
            Box({session: session, props: sibling});
            Support.CheckContextStage(s32(2));
            results[s32(0)].inner = Column({session: session, props: inner, children: (): void => {
                Support.CheckContextStage(s32(3));
            }});
        }});
    }});
}

export function SiblingFrame(session: Session, outer: NativeLayout.Props, first: NativeLayout.Props,
        box: NativeBox.Props, text_a: NativeText.Props, text_b: NativeText.Props,
        text_c: NativeText.Props, second: NativeLayout.Props, solo: NativeText.Props,
        kind: s32): NativeLayout.LayoutContainer {
    return Column({session: session, props: outer, children: (): void => {
        Column({session: session, props: first, children: (): void => {
            if (kind === s32(0)) {
                Support.CheckSiblingStage(s32(0));
                Support.CheckSiblingStage(s32(1));
                Support.CheckSiblingStage(s32(2));
                Support.CheckSiblingStage(s32(3));
                Box({session: session, props: box});
                Support.CheckSiblingStage(s32(4));
                Support.CheckSiblingStage(s32(5));
                Support.CheckSiblingStage(s32(6));
                Text({session: session, props: text_a});
                Support.CheckSiblingStage(s32(7));
                Text({session: session, props: text_b});
                Text({session: session, props: text_c});
            } else if (kind === s32(1)) {
                Support.CheckSiblingStage(s32(9));
                Support.CheckSiblingStage(s32(10));
                Box({session: session, props: box});
                Text({session: session, props: text_a});
                Text({session: session, props: text_b});
                Support.CheckSiblingStage(s32(11));
                Support.CheckSiblingStage(s32(12));
                Text({session: session, props: text_c});
            } else if (kind === s32(2)) {
                Box({session: session, props: box});
                Text({session: session, props: text_a});
                Text({session: session, props: text_b});
                Support.CheckSiblingStage(s32(15));
                Support.CheckSiblingStage(s32(16));
            } else {
                Box({session: session, props: box});
                Text({session: session, props: text_a});
                Support.CheckSiblingStage(s32(17));
                Text({session: session, props: text_b});
                Support.CheckSiblingStage(s32(18));
            }
        }});
        if (kind === s32(0)) {
            Column({session: session, props: second, children: (): void => {
                Support.CheckSiblingStage(s32(8));
                Text({session: session, props: solo});
            }});
        } else if (kind === s32(1)) {
            Column({session: session, props: second, children: (): void => {
                Support.CheckSiblingStage(s32(13));
                Support.CheckSiblingStage(s32(14));
                Text({session: session, props: solo});
            }});
        }
    }});
}

export function GradientCard(session: Session, props: NativeLayout.Props, face: StyleData,
        child: NativeBox.Props): NativeLayout.LayoutContainer {
    return StyledBox({session: session, props: props, face: face, children: (): void => {
        Box({session: session, props: child});
    }});
}

export function TransformedBox(session: Session, key: u64, class_name: string, bounds: Rectangle,
        text: boolean): NativeLayout.LayoutContainer {
    return Column({session: session,
        props: {key: key + u64(1), class_name: StyleClass(class_name), bounds: bounds},
        children: (): void => {
            if (text) {
                Text({session: session, props: {key: key + u64(2), text: "Save"}});
            }
        }});
}
