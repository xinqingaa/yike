// Resource identities come from proto-bridge.themes.json.artwork.
class YikeArtwork {
  const YikeArtwork(
    this.file,
    this.width,
    this.height,
    this.layers, {
    this.session,
  });
  final String file;
  final double width, height;
  final Map<String, String> layers;
  final String? session;
}

const yikeArtwork = <String, YikeArtwork>{
  'yike/mechanical-light': YikeArtwork(
    'asset/yike/artwork/mechanical-light.png',
    300,
    300,
    {
      'progress': 'asset/yike/artwork/mechanical-light--progress.png',
      'rest': 'asset/yike/artwork/mechanical-light--rest.png',
      'paused': 'asset/yike/artwork/mechanical-light--paused.png',
    },
    session: 'yike/mechanical-light-plain',
  ),
  'yike/mechanical-light-plain':
      YikeArtwork('asset/yike/artwork/mechanical-light-plain.png', 300, 300, {
        'progress': 'asset/yike/artwork/mechanical-light--progress.png',
        'rest': 'asset/yike/artwork/mechanical-light--rest.png',
        'paused': 'asset/yike/artwork/mechanical-light--paused.png',
      }),
  'yike/mechanical-dark': YikeArtwork(
    'asset/yike/artwork/mechanical-dark.png',
    300,
    300,
    {
      'progress': 'asset/yike/artwork/mechanical-dark--progress.png',
      'rest': 'asset/yike/artwork/mechanical-dark--rest.png',
      'paused': 'asset/yike/artwork/mechanical-dark--paused.png',
    },
    session: 'yike/mechanical-dark-plain',
  ),
  'yike/mechanical-dark-plain':
      YikeArtwork('asset/yike/artwork/mechanical-dark-plain.png', 300, 300, {
        'progress': 'asset/yike/artwork/mechanical-dark--progress.png',
        'rest': 'asset/yike/artwork/mechanical-dark--rest.png',
        'paused': 'asset/yike/artwork/mechanical-dark--paused.png',
      }),
  'yike/water-light':
      YikeArtwork('asset/yike/artwork/water-light.png', 236, 368, {
        'rest': 'asset/yike/artwork/water-light--rest.png',
        'wave': 'asset/yike/artwork/water-light--wave.png',
        'glass': 'asset/yike/artwork/water-light--glass.png',
      }),
  'yike/water-dark':
      YikeArtwork('asset/yike/artwork/water-dark.png', 236, 368, {
        'rest': 'asset/yike/artwork/water-dark--rest.png',
        'wave': 'asset/yike/artwork/water-dark--wave.png',
        'glass': 'asset/yike/artwork/water-dark--glass.png',
      }),
  'yike/sundial-light': YikeArtwork(
    'asset/yike/artwork/sundial-light.png',
    316,
    404,
    {'shadow': 'asset/yike/artwork/sundial-light--shadow.png'},
  ),
  'yike/sundial-dark': YikeArtwork(
    'asset/yike/artwork/sundial-dark.png',
    316,
    404,
    {'shadow': 'asset/yike/artwork/sundial-dark--shadow.png'},
  ),
};
