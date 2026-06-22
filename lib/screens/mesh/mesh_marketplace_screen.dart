import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/mesh_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mesh_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';

class MeshMarketplaceScreen extends StatefulWidget {
  const MeshMarketplaceScreen({super.key});

  @override
  State<MeshMarketplaceScreen> createState() => _MeshMarketplaceScreenState();
}

class _MeshMarketplaceScreenState extends State<MeshMarketplaceScreen> {
  @override
  void initState() {
	super.initState();
	WidgetsBinding.instance.addPostFrameCallback((_) {
	  context.read<MeshProvider>().listenToMarketplace();
	});
  }

  @override
  Widget build(BuildContext context) {
	final mesh = context.watch<MeshProvider>();

	return Scaffold(
	  appBar: AppBar(title: const Text('Local Marketplace')),
	  floatingActionButton: FloatingActionButton.extended(
		onPressed: () => _showCreateListingSheet(context),
		icon: const Icon(Icons.add_business),
		label: const Text('New Listing'),
	  ),
	  body: mesh.listings.isEmpty
		  ? const EmptyState(
			  icon: Icons.storefront_outlined,
			  title: 'No listings yet',
			  subtitle: 'Create the first local listing for produce, seeds, equipment, or services.',
			)
		  : ListView(
			  padding: const EdgeInsets.all(16),
			  children: [
				const SectionHeader(title: 'Farmer-to-farmer listings'),
				const SizedBox(height: 8),
				Text(
				  'Designed for local farm exchange today, with mesh-node synchronization later.',
				  style: Theme.of(context).textTheme.bodyMedium,
				),
				const SizedBox(height: 16),
				...mesh.listings.map(
				  (listing) => Card(
					child: Padding(
					  padding: const EdgeInsets.all(16),
					  child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
						  Row(
							children: [
							  Expanded(
								child: Text(
								  listing.title,
								  style: Theme.of(context)
									  .textTheme
									  .titleMedium
									  ?.copyWith(fontWeight: FontWeight.w800),
								),
							  ),
							  Chip(label: Text(listing.category.name)),
							],
						  ),
						  const SizedBox(height: 8),
						  Text(listing.description),
						  const SizedBox(height: 12),
						  Wrap(
							spacing: 12,
							runSpacing: 8,
							children: [
							  _MetaPill(
								icon: Icons.attach_money,
								label: '4${listing.price.toStringAsFixed(2)} / ${listing.unit}'.replaceFirst('4', ''),
							  ),
							  _MetaPill(
								icon: Icons.person_outline,
								label: listing.sellerName,
							  ),
							  if (listing.location != null && listing.location!.isNotEmpty)
								_MetaPill(
								  icon: Icons.place_outlined,
								  label: listing.location!,
								),
							],
						  ),
						  if (listing.tags.isNotEmpty) ...[
							const SizedBox(height: 12),
							Wrap(
							  spacing: 8,
							  runSpacing: 8,
							  children: listing.tags.map((tag) => Chip(label: Text(tag))).toList(),
							),
						  ],
						],
					  ),
					),
				  ),
				),
			  ],
			),
	);
  }

  void _showCreateListingSheet(BuildContext context) {
	final auth = context.read<AuthProvider>();
	final titleCtrl = TextEditingController();
	final descCtrl = TextEditingController();
	final priceCtrl = TextEditingController();
	final unitCtrl = TextEditingController(text: 'lb');
	final locationCtrl = TextEditingController();
	final tagsCtrl = TextEditingController();
	ListingCategory category = ListingCategory.produce;

	showModalBottomSheet<void>(
	  context: context,
	  isScrollControlled: true,
	  showDragHandle: true,
	  builder: (context) {
		return StatefulBuilder(
		  builder: (context, setModalState) {
			return Padding(
			  padding: EdgeInsets.fromLTRB(
				16,
				8,
				16,
				MediaQuery.of(context).viewInsets.bottom + 16,
			  ),
			  child: SingleChildScrollView(
				child: Column(
				  mainAxisSize: MainAxisSize.min,
				  crossAxisAlignment: CrossAxisAlignment.start,
				  children: [
					const Text(
					  'Create local listing',
					  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
					),
					const SizedBox(height: 12),
					TextField(
					  controller: titleCtrl,
					  decoration: const InputDecoration(labelText: 'Title'),
					),
					const SizedBox(height: 12),
					TextField(
					  controller: descCtrl,
					  minLines: 3,
					  maxLines: 5,
					  decoration: const InputDecoration(labelText: 'Description'),
					),
					const SizedBox(height: 12),
					DropdownButtonFormField<ListingCategory>(
					  value: category,
					  items: ListingCategory.values
						  .map(
							(value) => DropdownMenuItem(
							  value: value,
							  child: Text(value.name),
							),
						  )
						  .toList(),
					  onChanged: (value) {
						if (value != null) {
						  setModalState(() => category = value);
						}
					  },
					  decoration: const InputDecoration(labelText: 'Category'),
					),
					const SizedBox(height: 12),
					Row(
					  children: [
						Expanded(
						  child: TextField(
							controller: priceCtrl,
							keyboardType:
								const TextInputType.numberWithOptions(decimal: true),
							decoration: const InputDecoration(labelText: 'Price'),
						  ),
						),
						const SizedBox(width: 12),
						Expanded(
						  child: TextField(
							controller: unitCtrl,
							decoration: const InputDecoration(labelText: 'Unit'),
						  ),
						),
					  ],
					),
					const SizedBox(height: 12),
					TextField(
					  controller: locationCtrl,
					  decoration: const InputDecoration(labelText: 'Location (optional)'),
					),
					const SizedBox(height: 12),
					TextField(
					  controller: tagsCtrl,
					  decoration: const InputDecoration(
						labelText: 'Tags (comma separated)',
					  ),
					),
					const SizedBox(height: 16),
					Row(
					  children: [
						Expanded(
						  child: OutlinedButton(
							onPressed: () => Navigator.of(context).pop(),
							child: const Text('Cancel'),
						  ),
						),
						const SizedBox(width: 12),
						Expanded(
						  child: ElevatedButton(
							onPressed: () async {
							  final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
							  if (auth.userId == null || titleCtrl.text.trim().isEmpty) {
								return;
							  }

							  await context.read<MeshProvider>().createListing(
									sellerId: auth.userId!,
									sellerName: auth.user?.displayName ?? 'Farmer',
									title: titleCtrl.text.trim(),
									description: descCtrl.text.trim(),
									price: price,
									unit: unitCtrl.text.trim().isEmpty
										? 'item'
										: unitCtrl.text.trim(),
									category: category,
									location: locationCtrl.text.trim(),
									tags: tagsCtrl.text
										.split(',')
										.map((tag) => tag.trim())
										.where((tag) => tag.isNotEmpty)
										.toList(),
								  );

							  if (context.mounted) {
								Navigator.of(context).pop();
							  }
							},
							child: const Text('Create'),
						  ),
						),
					  ],
					),
				  ],
				),
			  ),
			);
		  },
		);
	  },
	);
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
	return Container(
	  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
	  decoration: BoxDecoration(
		color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
		borderRadius: BorderRadius.circular(999),
	  ),
	  child: Row(
		mainAxisSize: MainAxisSize.min,
		children: [
		  Icon(icon, size: 16),
		  const SizedBox(width: 6),
		  Text(label),
		],
	  ),
	);
  }
}
