/// Bridges the page-level back callback to the active WebShell instance.
export class BackDispatcher {
  static handler: () => boolean = () => false;
}
