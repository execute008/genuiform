// Simple brand name component
export default function Brand({ className = '', as: Tag = 'span' }) {
  return (
    <Tag className={`brand ${className}`.trim()}>
      genUIform
    </Tag>
  );
}
