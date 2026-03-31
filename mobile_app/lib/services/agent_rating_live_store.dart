import 'dart:async';

class AgentRatingLiveUpdate {
  final String agentId;
  final double averageRating;
  final int ratingCount;

  const AgentRatingLiveUpdate({
    required this.agentId,
    required this.averageRating,
    required this.ratingCount,
  });
}

class AgentRatingLiveStore {
  AgentRatingLiveStore._();

  static final AgentRatingLiveStore instance = AgentRatingLiveStore._();

  final StreamController<AgentRatingLiveUpdate> _controller =
      StreamController<AgentRatingLiveUpdate>.broadcast();

  Stream<AgentRatingLiveUpdate> get stream => _controller.stream;

  void emit(AgentRatingLiveUpdate update) {
    if (_controller.isClosed) return;
    _controller.add(update);
  }
}
